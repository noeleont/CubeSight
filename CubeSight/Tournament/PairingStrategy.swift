//
//  PairingStrategy.swift
//  CubeSight
//
//  Created by Noe Thalheim on 22.09.2024.
//

protocol PairingStrategy {
  func createPairings(for players: [Player], with performance: [Player: PlayerPerformance])
    -> [Match]
}

struct SwissPairingStrategy: PairingStrategy {
  func createPairings(
    for players: [Player], with performance: borrowing [Player: PlayerPerformance]
  ) -> [Match] {

    func hasPlayed(_ player1: Player, _ player2: Player) -> Bool {
      return performance[player1]?.opponents.contains(player2) ?? false
    }

    let unpairedPlayers = players.sorted {
      (performance[$0]?.matchPoints ?? 0) > (performance[$1]?.matchPoints ?? 0)
    }

    var matches: [Match] = []
    var remainingPlayers = unpairedPlayers

    while remainingPlayers.count >= 2 {
      let player1 = remainingPlayers.removeFirst()

      if let player2Index = remainingPlayers.firstIndex(where: { !hasPlayed(player1, $0) }) {
        let player2 = remainingPlayers.remove(at: player2Index)
        matches.append(Match(player1: player1, player2: player2))
      } else {
        let player2 = remainingPlayers.removeFirst()
        matches.append(Match(player1: player1, player2: player2))
      }
    }
    return matches
  }
}
