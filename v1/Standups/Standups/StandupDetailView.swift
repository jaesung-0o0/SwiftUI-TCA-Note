//
//  StandupDetailView.swift
//  Standups
//
//  Created by Jaesung Lee on 2023/09/05.
//

import SwiftUI
import ComposableArchitecture

struct StandupDetailFeature: Reducer {
    struct State: Equatable {
        var standup: Standup
        
        @PresentationState var editStandup: StandupFormFeature.State?
    }
    
    enum Action {
        case deleteButtonTapped
        case deleteMeetings(atOffsets: IndexSet)
        
        // Edit
        case editButtonTapped
        case cancelEditStandupButtonTapped
        case saveStandupButtonTapped
        case editStandup(PresentationAction<StandupFormFeature.Action>)
    }
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .deleteButtonTapped:
                return .none
            case .deleteMeetings(atOffsets: let indices):
                state.standup.meetings.remove(atOffsets: indices)
                return .none
                
            case .editButtonTapped:
                state.editStandup = StandupFormFeature.State(
                    standup: state.standup
                )
                return .none

            case .cancelEditStandupButtonTapped:
                state.editStandup = nil
                return .none
                
            case .saveStandupButtonTapped:
                guard let standup = state.editStandup?.standup else {
                    return .none
                }
                state.standup = standup
                state.editStandup = nil
                return .none
                
            case .editStandup:
                return .none
            }
        }
        .ifLet(\.$editStandup, action: /Action.editStandup) {
            StandupFormFeature()
        }
    }
}

struct StandupDetailView: View {
    let store: StoreOf<StandupDetailFeature>
    
    var body: some View {
        WithViewStore(self.store, observe: { $0 }) { viewStore in
            List {
                Section {
                    NavigationLink {
                        
                    } label: {
                        Label("미팅 시작하기", systemImage: "timer")
                            .font(.headline)
                            .foregroundStyle(Color.accentColor)
                    }
                    
                    HStack {
                        Label("길이", systemImage: "clock")
                        
                        Spacer()
                        
                        Text(viewStore.standup.duration.formatted(.units()))
                    }
                    
                    HStack {
                        Label("테마", systemImage: "paintpalette")
                        
                        Spacer()
                        
                        Text(viewStore.standup.theme.name)
                            .padding(4)
                            .foregroundStyle(viewStore.standup.theme.accentColor)
                            .background(viewStore.standup.theme.mainColor)
                            .clipShape(.rect(cornerRadius: 4))
                    }
                } header: {
                    Text("스탠드업 정보")
                }
                
                if !viewStore.standup.meetings.isEmpty {
                    Section {
                        ForEach(viewStore.standup.meetings) { meeting in
                            NavigationLink {
                                
                            } label: {
                                HStack {
                                    Image(systemName: "calendar")
                                    
                                    Text(meeting.date, style: .date)
                                    
                                    Text(meeting.date, style: .time)
                                }
                            }
                        }
                        .onDelete { indices in
                            viewStore.send(.deleteMeetings(atOffsets: indices))
                        }
                    } header: {
                        Text("이전 미팅")
                    }
                }
                
                Section {
                    ForEach(viewStore.standup.attendees) { attendee in
                        Label(attendee.name, systemImage: "person")
                    }
                } header: {
                    Text("참석자 명단")
                }
                
                Section {
                    Button("삭제") {
                        viewStore.send(.deleteButtonTapped)
                    }
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(viewStore.standup.title)
            .toolbar {
                Button("편집") {
                    viewStore.send(.editButtonTapped)
                }
            }
            .sheet(
                store: self.store.scope(
                    state: \.$editStandup,
                    action: { .editStandup($0) }
                )
            ) { store in
                NavigationStack {
                    StandupForm(store: store)
                        .toolbar {
                            ToolbarItem {
                                Button("저장") {
                                    viewStore.send(.saveStandupButtonTapped)
                                }
                            }
                            
                            ToolbarItem(placement: .cancellationAction) {
                                Button("취소") {
                                    viewStore.send(.cancelEditStandupButtonTapped)
                                }
                            }
                        }
                }
            }
        }
    }
}

#Preview {
    MainActor.assumeIsolated {
        NavigationStack {
            StandupDetailView(
                store: Store(
                    initialState: StandupDetailFeature.State(standup: .mock),
                    reducer: { StandupDetailFeature() }
                )
            )
        }
    }
}