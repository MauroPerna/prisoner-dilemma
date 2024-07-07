// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract PrisonersDilemma {
	uint256 public entryFee = 1 gwei;
	uint256 public roundDuration = 1 minutes; // Duración de cada ronda
	address public owner;

	struct Player {
		uint256 balance;
		uint256 score;
		bool inGame;
		bool decision; // true = cooperate, false = defect
		bool decided;
		uint256 currentRoom;
	}

	struct Room {
		address player1;
		address player2;
		bool active;
		uint256 roundEnd;
	}

	mapping(address => Player) public players;
	Room[] public rooms;

	event GameStarted(
		address indexed player1,
		address indexed player2,
		uint256 roomId
	);
	event DecisionMade(address indexed player, uint256 roomId, bool decision);
	event RewardsDistributed(uint256 roomId, address player1, address player2);
	event PlayerJoined(address indexed player, uint256 roomId);
	event RoomCreated(uint256 roomId, address player);
	event RoundReset(uint256 roomId);

	modifier onlyOwner() {
		require(msg.sender == owner, "Not the contract owner");
		_;
	}

	modifier onlyPlayer() {
		require(players[msg.sender].inGame, "Not a registered player");
		_;
	}

	constructor() {
		owner = msg.sender;
	}

	function joinGame() public payable {
		require(msg.value == entryFee, "Must send exactly 1 gwei");
		require(!players[msg.sender].inGame, "Already in game");

		players[msg.sender] = Player({
			balance: msg.value,
			score: msg.value,
			inGame: true,
			decision: false,
			decided: false,
			currentRoom: 0
		});

		matchPlayer();
	}

	function matchPlayer() internal {
		for (uint256 i = 0; i < rooms.length; i++) {
			if (
				rooms[i].active &&
				(rooms[i].player1 == address(0) ||
					rooms[i].player2 == address(0))
			) {
				if (rooms[i].player1 == address(0)) {
					rooms[i].player1 = msg.sender;
				} else {
					rooms[i].player2 = msg.sender;
					rooms[i].roundEnd = block.timestamp + roundDuration;
					emit GameStarted(rooms[i].player1, rooms[i].player2, i);
				}
				players[msg.sender].currentRoom = i;
				players[msg.sender].inGame = true; // Update inGame status
				emit PlayerJoined(msg.sender, i);
				return;
			}
		}
		rooms.push(
			Room({
				player1: msg.sender,
				player2: address(0),
				active: true,
				roundEnd: block.timestamp + roundDuration // Set the round end time for new room
			})
		);
		uint256 newRoomId = rooms.length - 1;
		players[msg.sender].currentRoom = newRoomId;
		players[msg.sender].inGame = true; // Update inGame status
		emit RoomCreated(newRoomId, msg.sender);
	}

	function makeDecision(bool decision) public onlyPlayer {
		uint256 roomId = players[msg.sender].currentRoom;
		require(roomId < rooms.length, "Invalid room");
		Room storage room = rooms[roomId];
		require(room.active, "Room is not active");
		require(block.timestamp <= room.roundEnd, "Round has ended");

		if (msg.sender == room.player1) {
			players[msg.sender].decision = decision;
			players[msg.sender].decided = true;
		} else if (msg.sender == room.player2) {
			players[msg.sender].decision = decision;
			players[msg.sender].decided = true;
		}

		emit DecisionMade(msg.sender, roomId, decision);

		if (players[room.player1].decided && players[room.player2].decided) {
			distributeRewards(roomId);
		}
	}

	function distributeRewards(uint256 roomId) internal {
		Room storage room = rooms[roomId];
		Player storage player1 = players[room.player1];
		Player storage player2 = players[room.player2];

		if (block.timestamp > room.roundEnd) {
			// Round has ended without decisions from both players, refund entry fees
			if (!player1.decided) {
				player1.inGame = false;
				(bool success1, ) = room.player1.call{ value: player1.balance }(
					""
				);
				require(success1, "Refund to player1 failed");
				player1.balance = 0;
				player1.score = 0;
			}
			if (!player2.decided) {
				player2.inGame = false;
				(bool success2, ) = room.player2.call{ value: player2.balance }(
					""
				);
				require(success2, "Refund to player2 failed");
				player2.balance = 0;
				player2.score = 0;
			}
			room.active = false;
			emit RoundReset(roomId);
			return;
		}

		if (player1.decision && player2.decision) {
			// Both cooperate: Slightly reduce both balances to simulate a small penalty
			player1.balance = (player1.balance * 9) / 10;
			player2.balance = (player2.balance * 9) / 10;
		} else if (!player1.decision && player2.decision) {
			// Player 1 defects, Player 2 cooperates: Player 1 gains, Player 2 loses
			uint256 amount = (player2.balance * 6) / 10;
			player2.balance = player2.balance - amount; // Player 2 loses 60% of balance
			player1.balance = player1.balance + amount; // Player 1 gains the amount Player 2 lost
		} else if (player1.decision && !player2.decision) {
			// Player 1 cooperates, Player 2 defects: Player 1 loses, Player 2 gains
			uint256 amount = (player1.balance * 6) / 10;
			player1.balance = player1.balance - amount; // Player 1 loses 60% of balance
			player2.balance = player2.balance + amount; // Player 2 gains the amount Player 1 lost
		} else {
			// Both defect: Both lose half of their balance
			player1.balance = player1.balance / 2;
			player2.balance = player2.balance / 2;
		}

		player1.score = player1.balance;
		player2.score = player2.balance;

		player1.decided = false;
		player2.decided = false;

		emit RewardsDistributed(roomId, room.player1, room.player2);

		// Reset room for next round
		room.roundEnd = block.timestamp + roundDuration;
	}

	function withdraw() public onlyPlayer {
		uint256 balance = players[msg.sender].balance;
		require(balance > 0, "No balance to withdraw");

		// Remove the player from the current room
		uint256 currentRoom = players[msg.sender].currentRoom;
		if (rooms[currentRoom].player1 == msg.sender) {
			rooms[currentRoom].player1 = address(0);
		} else if (rooms[currentRoom].player2 == msg.sender) {
			rooms[currentRoom].player2 = address(0);
		}

		delete players[msg.sender];

		(bool success, ) = msg.sender.call{ value: balance }("");
		require(success, "Withdrawal failed");
	}

	function getRanking()
		public
		view
		returns (address[] memory, uint256[] memory)
	{
		uint256 playerCount = 0;
		for (uint256 i = 0; i < rooms.length; i++) {
			if (rooms[i].player1 != address(0)) playerCount++;
			if (rooms[i].player2 != address(0)) playerCount++;
		}

		address[] memory addresses = new address[](playerCount);
		uint256[] memory scores = new uint256[](playerCount);
		uint256 index = 0;
		address[] memory addedAddresses = new address[](playerCount);

		for (uint256 i = 0; i < rooms.length; i++) {
			if (rooms[i].player1 != address(0)) {
				bool alreadyAdded = false;
				for (uint256 j = 0; j < index; j++) {
					if (addedAddresses[j] == rooms[i].player1) {
						alreadyAdded = true;
						break;
					}
				}
				if (!alreadyAdded) {
					addresses[index] = rooms[i].player1;
					scores[index] = players[rooms[i].player1].score;
					addedAddresses[index] = rooms[i].player1;
					index++;
				}
			}
			if (rooms[i].player2 != address(0)) {
				bool alreadyAdded = false;
				for (uint256 j = 0; j < index; j++) {
					if (addedAddresses[j] == rooms[i].player2) {
						alreadyAdded = true;
						break;
					}
				}
				if (!alreadyAdded) {
					addresses[index] = rooms[i].player2;
					scores[index] = players[rooms[i].player2].score;
					addedAddresses[index] = rooms[i].player2;
					index++;
				}
			}
		}

		return (addresses, scores);
	}

	function getPlayersByRooms()
		public
		view
		returns (
			address[] memory,
			uint256[] memory,
			uint256[] memory,
			bool[] memory
		)
	{
		uint256 playerCount = 0;
		for (uint256 i = 0; i < rooms.length; i++) {
			if (rooms[i].player1 != address(0)) playerCount++;
			if (rooms[i].player2 != address(0)) playerCount++;
		}

		address[] memory addresses = new address[](playerCount);
		uint256[] memory balances = new uint256[](playerCount);
		uint256[] memory roomsIds = new uint256[](playerCount);
		bool[] memory inGames = new bool[](playerCount);

		uint256 index = 0;
		for (uint256 i = 0; i < rooms.length; i++) {
			if (rooms[i].player1 != address(0)) {
				addresses[index] = rooms[i].player1;
				balances[index] = players[rooms[i].player1].balance;
				roomsIds[index] = i;
				inGames[index] = players[rooms[i].player1].inGame;
				index++;
			}
			if (rooms[i].player2 != address(0)) {
				addresses[index] = rooms[i].player2;
				balances[index] = players[rooms[i].player2].balance;
				roomsIds[index] = i;
				inGames[index] = players[rooms[i].player2].inGame;
				index++;
			}
		}

		return (addresses, balances, roomsIds, inGames);
	}

	function getPlayers()
		public
		view
		returns (
			address[] memory,
			uint256[] memory,
			uint256[] memory,
			bool[] memory,
			bool[] memory,
			bool[] memory,
			uint256[] memory
		)
	{
		uint256 playerCount = 0;
		for (uint256 i = 0; i < rooms.length; i++) {
			if (rooms[i].player1 != address(0)) playerCount++;
			if (rooms[i].player2 != address(0)) playerCount++;
		}

		address[] memory addresses = new address[](playerCount);
		uint256[] memory balances = new uint256[](playerCount);
		uint256[] memory scores = new uint256[](playerCount);
		bool[] memory inGames = new bool[](playerCount);
		bool[] memory decisions = new bool[](playerCount);
		bool[] memory decideds = new bool[](playerCount);
		uint256[] memory currentRooms = new uint256[](playerCount);

		uint256 index = 0;
		for (uint256 i = 0; i < rooms.length; i++) {
			if (rooms[i].player1 != address(0)) {
				addresses[index] = rooms[i].player1;
				balances[index] = players[rooms[i].player1].balance;
				scores[index] = players[rooms[i].player1].score;
				inGames[index] = players[rooms[i].player1].inGame;
				decisions[index] = players[rooms[i].player1].decision;
				decideds[index] = players[rooms[i].player1].decided;
				currentRooms[index] = players[rooms[i].player1].currentRoom;
				index++;
			}
			if (rooms[i].player2 != address(0)) {
				addresses[index] = rooms[i].player2;
				balances[index] = players[rooms[i].player2].balance;
				scores[index] = players[rooms[i].player2].score;
				inGames[index] = players[rooms[i].player2].inGame;
				decisions[index] = players[rooms[i].player2].decision;
				decideds[index] = players[rooms[i].player2].decided;
				currentRooms[index] = players[rooms[i].player2].currentRoom;
				index++;
			}
		}

		return (
			addresses,
			balances,
			scores,
			inGames,
			decisions,
			decideds,
			currentRooms
		);
	}

	function getContractBalance() public view returns (uint256) {
		return address(this).balance;
	}
}
