import Numerics
import SwiftData
import Testing

@testable import CubeSight

@MainActor
struct SwissPairingTests {
  let context: ModelContext

  init() async throws {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(
      for: TournamentPlayer.self, Tournament.self, TournamentRound.self, TournamentMatch.self, configurations: config)
    context = container.mainContext
  }

  /// Helper method to create a new round with proper SwiftData insertion
  private func createNextRound(
    for tournament: Tournament,
    using strategy: PairingStrategy = SwissPairingStrategy()
  ) throws -> TournamentRound {
    // Validate we can proceed
    #expect(
      tournament.canStartNextRound,
      "Tournament should be able to start next round"
    )

    // Generate matches
    guard let matches = tournament.createNextRoundMatches(using: strategy) else {
      struct PairingError: Error {}
      throw PairingError()
    }

    // Create and insert the round
    let newRound = TournamentRound(
      tournament: tournament,
      matches: matches,
      roundIndex: tournament.nextRoundIndex
    )

//    context.insert(newRound)
    try context.save()

    return newRound
  }

  @Test("Test looser and winner pairing one round")
  func testPairingOneRound() async throws {
    let winnerNames = ["Alice", "Bob", "Charlie", "David"]
    let looserNames = ["Eve", "Frank", "Grace", "Henry"]
    let playerNames = winnerNames + looserNames

    // Create unique players with UUID-based names to avoid unique constraint issues
    let players = playerNames.enumerated().map { index, name in
      TournamentPlayer(player: Player(name: "\(name)_\(index)"))
    }

    let tournament = Tournament(players: players)
    // No need to explicitly insert - SwiftData will handle it through relationships
    try context.save()

    // Create first round using new approach
    let round1 = try createNextRound(for: tournament)

    // Score matches - check if player name starts with winner name
    for match in round1.matches {
      let player1IsWinner = winnerNames.contains { match.player1.name.starts(with: $0) }
      if player1IsWinner {
        match.complete(player1Wins: 2, player2Wins: 0, draws: 0)
      } else {
        match.complete(player1Wins: 0, player2Wins: 2, draws: 0)
      }
    }
    try context.save()

    // Create second round
    let round2 = try createNextRound(for: tournament)

    // Check pairings in round 2
    for match in round2.matches {
      let player1IsWinner = winnerNames.contains { match.player1.name.starts(with: $0) }
      let player2IsWinner = winnerNames.contains { match.player2.name.starts(with: $0) }
      #expect(
        (player1IsWinner && player2IsWinner) || (!player1IsWinner && !player2IsWinner),
        "Round 2 should separate winners and losers"
      )
    }
  }

  @Test("Test pairing across multiple rounds")
  func testPairingMultipleRounds() async throws {
    let playerNames = ["Alice", "Bob", "Charlie", "David", "Eve", "Frank", "Grace", "Henry"]

    // Create unique players with UUID-based names to avoid unique constraint issues
    let players = playerNames.enumerated().map { index, name in
      TournamentPlayer(player: Player(name: "\(name)_\(index)"))
    }
    let tournament = Tournament(players: players)
    // No need to explicitly insert - SwiftData will handle it through relationships
    try context.save()

    // Round 1: Create and score
    let round1 = try createNextRound(for: tournament)

    // Track winners/losers by reference, not by name
    let winnersRoundOne = Set(round1.matches.map { $0.player1 })
    let losersRoundOne = Set(round1.matches.map { $0.player2 })

    for match in round1.matches {
      let player1WonRound = winnersRoundOne.contains(match.player1)
      match.complete(
        player1Wins: player1WonRound ? 2 : 0,
        player2Wins: player1WonRound ? 0 : 2,
        draws: 0
      )
    }
    try context.save()

    // Round 2: Create and verify
    let round2 = try createNextRound(for: tournament)

    for match in round2.matches {
      let bothWinners = [match.player1, match.player2].allSatisfy {
        winnersRoundOne.contains($0)
      }
      let bothLosers = [match.player1, match.player2].allSatisfy {
        losersRoundOne.contains($0)
      }
      #expect(bothWinners || bothLosers, "Round 2 should pair players based on Round 1 records")
    }

    // Score round 2
    let winnersRoundTwo = Set(round2.matches.map { $0.player1 })
    let losersRoundTwo = Set(round2.matches.map { $0.player2 })

    for match in round2.matches {
      let player1WonRound = winnersRoundTwo.contains(match.player1)
      match.complete(
        player1Wins: player1WonRound ? 2 : 0,
        player2Wins: player1WonRound ? 0 : 2,
        draws: 0
      )
    }
    try context.save()

    // Round 3: Create and verify stratification
    let round3 = try createNextRound(for: tournament)

    let bothWon = winnersRoundOne.intersection(winnersRoundTwo)
    let bothLost = losersRoundOne.intersection(losersRoundTwo)
    let middleGroup = Set(tournament.players).subtracting(bothWon.union(bothLost))

    for match in round3.matches {
      let both2_0 = [match.player1, match.player2].allSatisfy { bothWon.contains($0) }
      let both1_1 = [match.player1, match.player2].allSatisfy { middleGroup.contains($0) }
      let both0_2 = [match.player1, match.player2].allSatisfy { bothLost.contains($0) }

      #expect(both2_0 || both1_1 || both0_2, "Round 3 should pair players based on overall records")
    }
  }
}
