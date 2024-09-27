//
//  App.swift
//  Standups
//
//  Created by Jaesung Lee on 2023/09/09.
//

import SwiftUI
import ComposableArchitecture

struct AppFeature: Reducer {
    struct State: Equatable {
        /// 어떤 feature가 현재 스택에서 돌아가는 중인지
        ///
        /// 스택은 다양한 타입의 화면을 표시할 수 있음.
        /// 예를 들어, 세부 사항에서 회의 기능을 drill down 하고 과거 회의 목록까지 drill down 하는 앱
        /// 이런 경우 ``StandupDetailFeature``과 같이 작업에 사용할 경로하나만 지정하면 다른 타입의 대상을 통합하기 어려움
        /// 스택의 화면들의 위치에 대한 enum 을 모델링해야함.
        /// 그것이 바로, ``AppFeature/Path`` 와 같은 **Nested Reducer**를 선언하는 것
        var path = StackState<Path.State>()
        
        var standupsList = StandupsListFeature.State()
    }
    
    enum Action: Equatable {
        case path(StackAction<Path.State, Path.Action>)
        case standupsList(StandupsListFeature.Action)
    }
    
    struct Path: Reducer {
        // 어떤 스크린이 스택에 있을 지에 대한 enum
        enum State: Equatable {
            case detail(StandupDetailFeature.State)
            case recordMeeting(RecordMeetingFeature.State)
        }
        
        enum Action: Equatable {
            case detail(StandupDetailFeature.Action)
            case recordMeeting(RecordMeetingFeature.Action)
        }
        
        var body: some ReducerOf<Self> {
            Scope(
                state: /State.detail,
                action: /Action.detail,
                child: { StandupDetailFeature() }
            )
            
            Scope(
                state: /State.recordMeeting,
                action: /Action.recordMeeting,
                child: { RecordMeetingFeature() }
            )
        }
    }
    
    @Dependency(\.date.now) var now
    @Dependency(\.uuid) var uuid
    
    var body: some ReducerOf<Self> {
        // 액션이 들어오면 먼저 실행
        Scope(
            state: \.standupsList,
            action: /Action.standupsList
        ) {
            StandupsListFeature()
        }
        
        Reduce { state, action in
            switch action {
            
            case let .path(.element(id: _, action: .detail(.delegate(action)))):
                switch action {
                case let .standupUpdated(standup):
                    state.standupsList.standups[id: standup.id] = standup
                    return .none
                    
                case let .deleteStandup(id: id):
                    state.standupsList.standups.remove(id: id)
                    return .none
                }
                
            case .path(.element(id: let id, action: .recordMeeting(.delegate(let action)))):
                switch action {
                case .saveMeeting:
                    guard let detailID = state.path.ids.dropLast().last else {
                        XCTFail("Record Meeting이 현재 네비게이션 스택의 마지막 요소이기 때문에 Detail Feature 가 처리되어야 합니다.")
                        return .none
                    }
                    // TODO:
                    state
                        .path[id: detailID, case: /Path.State.detail]?
                        .standup
                        .meetings
                        .insert(
                            Meeting(
                                id: self.uuid(),
                                date: self.now,
                                transcript: "N/A"
                            ),
                            at: 0
                        )
                    guard let standup = state.path[id: id, case: /Path.State.detail]?.standup else {
                        return .none
                    }
                    state.standupsList.standups[id: standup.id] = standup
                    return .none
                }
                
            case .path:
                return .none
                
            case .standupsList:
                return .none
            }
        }
        /// `ifLet` -> sheets, pop over
        /// collection 다룰 때는 `forEach`.
        .forEach(\.path, action: /Action.path) { /// `StateState`가 `propertyWrapper`가 아니기 때문에 `\.$path` 와 같이 `$` 기호(`projected value` 에 접근하기 위함) 쓸 필요 없음
            Path()
        }
    }
}

struct AppView: View {
    let store: StoreOf<AppFeature>
    
    var body: some View {
        NavigationStackStore(
            self.store.scope(state: \.path, action: { .path($0) })
        ) {
            // root
            
            StandupsList(
                store: self.store.scope(
                    state: \.standupsList,
                    action: { .standupsList($0) }
                )
            )
        } destination: { state in
            switch state {
            case .detail:
                CaseLet(
                    /AppFeature.Path.State.detail,
                    action: AppFeature.Path.Action.detail,
                    then: StandupDetailView.init(store:)
                )
                
            case .recordMeeting:
                CaseLet(
                    /AppFeature.Path.State.recordMeeting,
                    action: AppFeature.Path.Action.recordMeeting,
                    then: RecordMeetingView.init(store:)
                )
            }
        }
    }
}

/**
 // Future
 
 ```swift
 destination: { store in // state 가 아닌 store
    switch store.state {
    case .detail:
        if let store = store.scope(state: \.detail, action: { .detail($0) }) {
            StandupDetailView(store: store)
        }
    }
 }
 ```
                
 */


#Preview {
    AppView(
        store: Store(
            initialState: AppFeature.State(
                standupsList: StandupsListFeature.State(standups: [.mock])
            ),
            reducer: { AppFeature() }
        )
    )
}

#Preview("빠른 회의 종료") {
    var standup = Standup.mock
    standup.duration = .seconds(6)
    
    return AppView(
        store: Store(
            initialState: AppFeature.State(
                path: StackState([
                    .detail(StandupDetailFeature.State(standup: standup)),
                    .recordMeeting(RecordMeetingFeature.State(standup: standup))
                ]),
                standupsList: StandupsListFeature.State(standups: [standup])
            ),
            reducer: { AppFeature() }
        )
    )
}
