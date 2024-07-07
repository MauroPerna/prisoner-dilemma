"use client";

import React, { useEffect } from "react";
import { formatEther } from "ethers";
import { formatGwei, parseGwei } from "viem";
import { useAccount } from "wagmi";
import { useScaffoldReadContract, useScaffoldWriteContract } from "~~/hooks/scaffold-eth";

const PrisonersDilemma = () => {
  const { address: connectedAddress } = useAccount();

  const { data: playersDataByRooms, refetch: refetchPlayersDataByRooms } = useScaffoldReadContract({
    contractName: "PrisonersDilemma",
    functionName: "getPlayersByRooms",
  });

  const { data: rankingData, refetch: refetchRankingData } = useScaffoldReadContract({
    contractName: "PrisonersDilemma",
    functionName: "getRanking",
  });

  const { data: playersData, refetch: refetchPlayersData } = useScaffoldReadContract({
    contractName: "PrisonersDilemma",
    functionName: "getPlayers",
  });

  const { data: contractBalance, refetch: refetchContractBalance } = useScaffoldReadContract({
    contractName: "PrisonersDilemma",
    functionName: "getContractBalance",
  });

  const { writeContractAsync: joinGame } = useScaffoldWriteContract("PrisonersDilemma");
  const { writeContractAsync: makeDecision } = useScaffoldWriteContract("PrisonersDilemma");
  const { writeContractAsync: withdraw } = useScaffoldWriteContract("PrisonersDilemma");

  const handleJoinGame = async () => {
    await joinGame({
      functionName: "joinGame",
      value: parseGwei("1"),
    });
    refetchPlayersDataByRooms();
    refetchPlayersData();
    refetchRankingData();
    refetchContractBalance();
  };

  const handleMakeDecision = async (decision: boolean) => {
    await makeDecision({
      functionName: "makeDecision",
      args: [decision],
    });
    refetchPlayersDataByRooms();
    refetchPlayersData();
    refetchRankingData();
    refetchContractBalance();
  };

  const handleWithdraw = async () => {
    await withdraw({
      functionName: "withdraw",
    });
    refetchPlayersDataByRooms();
    refetchPlayersData();
    refetchRankingData();
    refetchContractBalance();
  };

  useEffect(() => {
    if (connectedAddress) {
      refetchPlayersDataByRooms();
      refetchPlayersData();
      refetchRankingData();
      refetchContractBalance();
    }
  }, [connectedAddress, refetchPlayersDataByRooms, refetchRankingData, refetchContractBalance, handleWithdraw]);

  let playerData = null;

  if (playersDataByRooms) {
    const [addresses, balances, roomsIds, inGames] = playersDataByRooms;
    const playerIndex = addresses.indexOf(connectedAddress || "");
    if (playerIndex !== -1) {
      playerData = {
        address: addresses[playerIndex],
        balance: balances[playerIndex],
        roomId: roomsIds[playerIndex],
        inGame: inGames[playerIndex],
      };
    }
  }

  const playerBalance = playerData ? formatGwei(playerData.balance) : "0";
  const isInGame = playerData ? true : false;

  console.log({ playersData });
  console.log("PlayerData:", playerData);

  let ranking: { address: string; balance: string }[] = [];

  if (rankingData && rankingData[0].length > 0) {
    ranking = rankingData[0].map((address: string, index: number) => ({
      address,
      balance: rankingData[1][index].toString(),
    }));

    // Ordenar el ranking en función de los balances
    ranking.sort((a, b) => parseFloat(b.balance) - parseFloat(a.balance));
  }

  const rooms: Record<string, { address: string; balance: string }[]> = {};

  if (playersDataByRooms && playersDataByRooms[0].length > 0) {
    const [addresses, balances, roomsIds] = playersDataByRooms;
    addresses.forEach((address: string, index: number) => {
      const roomId = roomsIds[index];
      if (!rooms[roomId.toString()]) {
        rooms[roomId.toString()] = [];
      }
      rooms[roomId.toString()].push({ address, balance: balances[index].toString() });
    });
  }

  return (
    <div>
      <h1 className="text-5xl font-bold">Prisoners Dilemma Game</h1>

      <div className="flex gap-2">
        <div className="mt-4 w-1/2">
          {isInGame ? (
            <div className="flex flex-col w-full">
              <div className="flex flex-start stats bg-primary text-primary-content">
                <div className="stat w-1/3 flex flex-wrap justify-center">
                  <div className="stat-title">Contract balance</div>
                  <div className="stat-value">{contractBalance ? formatGwei(contractBalance) : "0"} GWEI</div>
                </div>

                <div className="stat flex flex-col w-2/3">
                  <div className="stat-title">Your balance</div>
                  <div className="flex gap-2 items-center w-full">
                    <div className="stat-value">{playerBalance} GWEI</div>
                    <button className="stat-actions btn btn-sm mt-0" onClick={handleWithdraw}>
                      Withdrawal
                    </button>
                  </div>
                  <div className="flex gap-2 stat-actions">
                    <button className="btn btn-success mt-5" onClick={() => handleMakeDecision(true)}>
                      Cooperate
                    </button>
                    <button className="btn btn-warning mt-5" onClick={() => handleMakeDecision(false)}>
                      Defect
                    </button>
                  </div>
                </div>
              </div>
            </div>
          ) : (
            <button className="btn btn-primary mt-2" onClick={handleJoinGame}>
              Join Game (1 GWEI)
            </button>
          )}
        </div>
        <div className="mt-4 w-1/2">
          <h2 className="text-xl font-bold">Ranking</h2>
          {ranking.length > 0 ? (
            <div className="overflow-x-auto">
              <table className="table">
                {/* head */}
                <thead>
                  <tr>
                    <th>Position</th>
                    <th>Address</th>
                    <th>Balance</th>
                  </tr>
                </thead>
                <tbody>
                  {ranking.map((player, index) => (
                    <tr key={index}>
                      <th>{index + 1}</th>
                      <td>{player.address}: </td>
                      <td>{formatEther(player.balance)} ETH</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          ) : (
            <p>No ranking data available.</p>
          )}
        </div>
      </div>
      <div className="mt-8">
        <h2 className="text-xl font-bold">Duels by Room</h2>
        {Object.keys(rooms).length > 0 ? (
          Object.keys(rooms).map(roomId => (
            <div key={roomId} className="mb-4">
              <h3 className="text-lg font-bold">Room {roomId}</h3>
              <ul>
                <div className="flex w-full">
                  <div className="card flex item-center justify-center rounded-xl h-40 border border-red-600 bg-red-200 text-black rounded-box grid flex-grow place-items-center">
                    <div className="flex flex-wrap justify-center">
                      <span className="w-full">{rooms[roomId][0]?.address}</span>
                      <span className="text-xl">
                        {rooms[roomId][0]?.balance ? formatEther(rooms[roomId][0]?.balance) : 0} ETH
                      </span>
                    </div>
                  </div>
                  <div className="divider divider-horizontal divider-success">VS</div>
                  <div className="card flex item-center justify-center rounded-xl h-40 border border-blue-600 bg-blue-200 text-black rounded-box grid flex-grow place-items-center">
                    <div className="flex flex-wrap justify-center">
                      <span className="w-full">{rooms[roomId][1]?.address}</span>
                      <span className="text-xl">
                        {rooms[roomId][1]?.balance ? formatEther(rooms[roomId][1]?.balance) : 0} ETH
                      </span>
                    </div>
                  </div>
                </div>
              </ul>
            </div>
          ))
        ) : (
          <p>No duels available.</p>
        )}
      </div>
    </div>
  );
};

export default PrisonersDilemma;
