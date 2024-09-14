import SwiftData
import SwiftUI

struct TournamentView: View {
  @Bindable var viewModel: TournamentViewModel
  @Environment(\.modelContext) private var modelContext
  @Query private var players: [Player]

  var body: some View {
    NavigationView {
      Group {
        switch viewModel.state {
        case .setup:
          SetupView(viewModel: viewModel, players: players)
        case .inProgress(let tournament):
          TournamentProgressView(viewModel: viewModel, tournament: tournament)
        }
      }
      .navigationTitle("Tournament")
    }
  }
}

struct SetupView: View {
  @Bindable var viewModel: TournamentViewModel
  let players: [Player]
  @State private var selectedPlayers: Set<Player> = []

  var body: some View {
    VStack {
      List(players, selection: $selectedPlayers) { player in
        Text(player.name)
      }
      .environment(\.editMode, .constant(.active))

      Button("Start Tournament") {
        viewModel.startTournament(players: Array(selectedPlayers))
      }
      .disabled(selectedPlayers.count < 2)
      .padding()
    }
  }
}

struct TournamentProgressView: View {
  @Bindable var viewModel: TournamentViewModel
  let tournament: Tournament

  var body: some View {
    List {
      StandingsView(tournament: tournament)

      ForEach(tournament.rounds.indices, id: \.self) { roundIndex in
        Section(header: Text("Round \(roundIndex + 1)")) {
          ForEach(tournament.rounds[roundIndex].matches.indices, id: \.self) { matchIndex in
            MatchView(
              viewModel: viewModel, roundIndex: roundIndex, matchIndex: matchIndex,
              match: tournament.rounds[roundIndex].matches[matchIndex])
          }
        }
      }
    }
  }
}

struct StandingsView: View {
  let tournament: Tournament

  var body: some View {
    Section(header: Text("Standings")) {
      ForEach(
        Array(
          tournament.performance.keys.sorted {
            tournament.performance[$0]!.matchPoints > tournament.performance[$1]!.matchPoints
          }), id: \.self
      ) { player in
        HStack {
          Text(player.name)
          Spacer()
          Text("MP: \(tournament.performance[player]!.matchPoints)")
          Text("GP: \(tournament.performance[player]!.gamePoints)")
        }
      }
    }
  }
}

struct MatchView: View {
  @Bindable var viewModel: TournamentViewModel
  let roundIndex: Int
  let matchIndex: Int
  let match: Match
  @State private var player1Wins = 0
  @State private var player2Wins = 0
  @State private var draws = 0

  var body: some View {
    VStack {
      Text("\(match.player1.name) vs \(match.player2.name)")
      HStack {
        Stepper("P1 Wins: \(player1Wins)", value: $player1Wins, in: 0...3)
        Stepper("P2 Wins: \(player2Wins)", value: $player2Wins, in: 0...3)
        Stepper("Draws: \(draws)", value: $draws, in: 0...3)
      }
      Button("Submit Result") {
        viewModel.completeMatch(
          roundIndex: roundIndex, matchIndex: matchIndex, player1Wins: player1Wins,
          player2Wins: player2Wins, draws: draws)
      }
      .disabled(player1Wins + player2Wins + draws == 0 || match.isComplete())
    }
    .padding()
  }
}

#Preview {
  let config = ModelConfiguration(isStoredInMemoryOnly: true)
  let container = try! ModelContainer(
    for: Player.self, Tournament.self, Round.self, Match.self, configurations: config)

  let players = [
    Player(name: "Alice"),
    Player(name: "Bob"),
    Player(name: "Charlie"),
    Player(name: "David"),
  ]

  players.forEach { container.mainContext.insert($0) }

  let viewModel = TournamentViewModel(modelContext: container.mainContext)
  viewModel.startTournament(players: players)

  return TournamentView(viewModel: viewModel)
    .modelContainer(container)
}
