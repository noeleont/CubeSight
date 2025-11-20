import Foundation
import SwiftData

@Model
class Tournament {
  @Relationship(deleteRule: .cascade, inverse: \TournamentRound.tournament)
  var rounds: [TournamentRound] = []
  @Relationship var players:
    [TournamentPlayer] = []

  var createdAt: Date
  var status: TournamentStatus

  @available(*, deprecated, message: "Find another way to abstract. Strage UI behaviour results of this.")
  func startNextRound(strategy: PairingStrategy = SwissPairingStrategy()) {
    let newMatches = strategy.createPairings(for: players, with: performance)
    let newRound = TournamentRound(
      tournament: self,
      matches: newMatches,
      roundIndex: rounds.count
    )
    rounds.append(newRound)
  }

  init(players: [TournamentPlayer] = []) {
    self.createdAt = Date.now
    self.players = players
    self.status = .seating
  }
}

extension Tournament {
  /// Validates that the current round is complete and ready to advance
  var canStartNextRound: Bool {
    guard !rounds.isEmpty else { return true } // First round always allowed
    return rounds.last?.matches.allSatisfy { $0.isComplete } ?? false
  }

  /// Gets the next round number (purely computational)
  var nextRoundIndex: Int {
    rounds.count
  }

  /// Validates and creates matches for the next round
  /// Returns nil if validation fails
  func createNextRoundMatches(
    using strategy: PairingStrategy = SwissPairingStrategy()
  ) -> [TournamentMatch]? {
    // Validate we can proceed
    guard canStartNextRound else { return nil }

    // Generate pairings
    let matches = strategy.createPairings(
      for: players,
      with: performance
    )

    // Validate pairings (ensures strategy works correctly)
    guard !matches.isEmpty else { return nil }

    return matches
  }

  var performance: [TournamentPlayer: TournamentPlayerPerformance] {
    var performance = Dictionary(
      uniqueKeysWithValues: self.players.map {
        ($0, TournamentPlayerPerformance())
      }
    )

    let completeMatches =
      rounds
      .flatMap { $0.matches }
      .filter { $0.isComplete }

    for match in completeMatches {
      var player1Performance = performance[match.player1]
      player1Performance?.gameWins += match.player1Wins
      player1Performance?.gameLosses += match.player2Wins
      player1Performance?.draws += match.draws
      player1Performance?.opponents.append(match.player2)

      var player2Performance = performance[match.player2]
      player2Performance?.gameWins += match.player2Wins
      player2Performance?.gameLosses += match.player1Wins
      player2Performance?.draws += match.draws
      player2Performance?.opponents.append(match.player1)

      // Update match results
      if match.winner != nil {
        if match.player1Wins > match.player2Wins {
          player1Performance?.matchWins += 1
          player2Performance?.matchLosses += 1
        } else {
          player1Performance?.matchLosses += 1
          player2Performance?.matchWins += 1
        }
      }

      performance[match.player1] = player1Performance
      performance[match.player2] = player2Performance
    }

    return performance
  }
}

extension Tournament {
  @MainActor static var previewTournament: Tournament = Tournament(players: [
    TournamentPlayer(player: Player(name: "Alice")),
    TournamentPlayer(player: Player(name: "Bob")),
    TournamentPlayer(player: Player(name: "Carol")),
    TournamentPlayer(player: Player(name: "David")),
    TournamentPlayer(player: Player(name: "Eve")),
    TournamentPlayer(player: Player(name: "Frank")),
  ])

  @MainActor static func makeSampleTournaments(in context: ModelContainer) {
    context.mainContext.insert(previewTournament)
  }
}
