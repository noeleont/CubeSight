//
//  TournamentViewModel.swift
//  CubeSight
//
//  Created by Noe Thalheim on 22.09.2024.
//

import SwiftData

@Observable
class TournamentViewModel {
  enum State {
    case setup
    case inProgress(Tournament)
  }

  var state: State = .setup
  let modelContext: ModelContext

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  func startTournament(players: [Player]) {
    let tournament = Tournament(players: players)
    state = .inProgress(tournament)
    startNextRound()
  }

  func completeMatch(
    roundIndex: Int, matchIndex: Int, player1Wins: Int, player2Wins: Int, draws: Int
  ) {
    assert(player1Wins + player2Wins + draws > 0, "match must end with a winner or a draw")
    guard case .inProgress(var tournament) = state else { return }

    let match = tournament.rounds[roundIndex].matches[matchIndex]
    match.player1Wins = player1Wins
    match.player2Wins = player2Wins
    match.draws = draws
    match.winner = player1Wins > player2Wins ? match.player1 : match.player2

    // TODO: move this into a Finish Round button
    if isRoundComplete(roundIndex) {
      tournament.rounds[roundIndex].isCompleted = true
      if roundIndex == tournament.currentRoundIndex {
        startNextRound()
      }
    }
  }

  private func isRoundComplete(_ roundIndex: Int) -> Bool {
    guard case .inProgress(var tournament) = state else {
      fatalError("tournament must be in progress")
    }
    return tournament.rounds[roundIndex].matches.allSatisfy { $0.isComplete() }
  }

  private func startNextRound() {
    guard case .inProgress(var tournament) = state else {
      fatalError("tournament must be in progress")
    }
    //    assert(isRoundComplete(tournament.currentRoundIndex), "current round must be complete before starting a new one")

    let strategy = SwissPairingStrategy()
    //    TODO(performance): only add current round peformance, i.e. update tournament.performance instead
    tournament.invalidatePerformanceCache()

    let newMatches = strategy.createPairings(for: tournament.players, with: tournament.performance)
    newMatches.forEach { modelContext.insert($0) }

    let newRound = Round(matches: newMatches)
    modelContext.insert(newRound)

    tournament.rounds.append(newRound)
    tournament.currentRoundIndex += 1
  }
}
