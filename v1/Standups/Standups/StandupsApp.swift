//
//  StandupsApp.swift
//  Standups
//
//  Created by Jaesung Lee on 2023/08/31.
//

import SwiftUI
import ComposableArchitecture

@main
struct StandupsApp: App {
    var body: some Scene {
        WindowGroup {
            var standup = Standup.mock
            let _ = standup.duration = .seconds(6)
            
            AppView(
                store: Store(
                    initialState: AppFeature.State(
                        path: StackState([
                            .detail(
                                StandupDetailFeature.State(standup: standup)
                            ),
                            .recordMeeting(
                                RecordMeetingFeature.State(standup: standup)
                            ),
                        ]),
                        standupsList: StandupsListFeature.State(standups: [standup])
                    ),
                    reducer: { AppFeature() }
                )
            )
        }
    }
}

