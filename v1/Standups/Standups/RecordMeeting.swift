//
//  RecordMeeting.swift
//  Standups
//
//  Created by 이재성 on 10/15/23.
//

import ComposableArchitecture
import Speech
import SwiftUI

struct RecordMeetingFeature: Reducer {
    struct State: Equatable {
        var secondsElapsed = 0
        var speakerIndex = 0
        let standup: Standup // 왜 상수? 어떠한 변화도 안 줄 것이기 때문
        
        var durationRemaining: Duration {
            self.standup.duration - .seconds(self.secondsElapsed)
        }
    }
    enum Action: Equatable {
        case onTask
        case nextButtonTapped
        case endMeetingButtonTapped
        case timerTicked

        case delegate(Delegate)
        
        enum Delegate {
            case saveMeeting
        }
    }
    
    @Dependency(\.dismiss) var dismiss
    @Dependency(\.continuousClock) var clock
    @Dependency(\.speechClient) var speechClient
    
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .onTask:
                return .run { send in
                    /// `requestAuthorization` 를 swift concurrency 에서 쓸 수 있도록 변형
                    let status = await self.speechClient.requestAuthorization()
                    for await _ in self.clock.timer(interval: .seconds(1)) {
                        await send(.timerTicked)
                    }
                }
            case .nextButtonTapped:
                guard state.speakerIndex < state.standup.attendees.count - 1 else {
                    // TODO: Alert to end meeting
                    return .none
                }
                state.speakerIndex += 1
                state.secondsElapsed = state.speakerIndex * Int(
                    state.standup.durationPerAttendee.components.seconds
                )
                return .none
                
            case .endMeetingButtonTapped:
                return .none
                
            case .timerTicked:
                state.secondsElapsed += 1
                let secondsPerAttendee = Int(
                    state.standup.durationPerAttendee.components.seconds
                )
                if state.secondsElapsed.isMultiple(of: secondsPerAttendee) {
                    if state.speakerIndex == state.standup.attendees.count - 1 {
                        // TODO: End meeting
                        return .run { send in
                            /// `"어이~ saveMeeting 해줘"`
                            await send(.delegate(.saveMeeting))
                            await self.dismiss()
                        }
                    }
                    state.speakerIndex += 1
                }
                return .none
                
            case .delegate:
                return .none
            }
        }
    }
}

struct RecordMeetingView: View {
    let store: StoreOf<RecordMeetingFeature>
    
    var body: some View {
        WithViewStore(
            self.store, observe: { $0 }
        ) { viewStore in
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(viewStore.standup.theme.mainColor)
                
                VStack {
                    MeetingHeaderView(
                        secondsElapsed: viewStore.secondsElapsed,
                        durationRemaining: viewStore.durationRemaining,
                        theme: viewStore.standup.theme
                    )
                    MeetingTimerView(
                        standup: viewStore.standup,
                        speakerIndex: viewStore.speakerIndex
                    )
                    MeetingFooterView(
                        standup: viewStore.standup,
                        nextButtonTapped: {
                            viewStore.send(.nextButtonTapped)
                        },
                        speakerIndex: viewStore.speakerIndex
                    )
                }
            }
            .padding()
            .foregroundColor(viewStore.standup.theme.accentColor)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End meeting") {
                        viewStore.send(.endMeetingButtonTapped)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .task { await viewStore.send(.onTask).finish() }
            /// > **질문** `finish()` 가 뭐지?
            /// 
            /// [공식 문서 링크](https://developer.apple.com/documentation/swift/asyncstream/continuation/finish())
            ///
            /// 다음 반복 지점을 기다리는 작업을 재개하기 위해 이 함수를 호출하면 `nil`을 반환하게 되어, 반복이 끝났음을 나타냅니다.
            /// 이 함수를 여러 번 호출해도 효과가 없습니다. finish를 호출한 후에는 스트림이 종료 상태로 들어가 추가적인 요소를 생성하지 않습니다.
            ///
            /// `onTask` 안에서 for 루프가 돌고 있다
        }
    }
}

struct MeetingHeaderView: View {
    let secondsElapsed: Int
    let durationRemaining: Duration
    let theme: Theme
    
    var body: some View {
        VStack {
            ProgressView(value: self.progress)
                .progressViewStyle(
                    MeetingProgressViewStyle(theme: self.theme)
                )
            HStack {
                VStack(alignment: .leading) {
                    Text("Time Elapsed")
                        .font(.caption)
                    Label(
                        Duration.seconds(self.secondsElapsed)
                            .formatted(.units()),
                        systemImage: "hourglass.bottomhalf.fill"
                    )
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Time Remaining")
                        .font(.caption)
                    Label(
                        self.durationRemaining.formatted(.units()),
                        systemImage: "hourglass.tophalf.fill"
                    )
                    .font(.body.monospacedDigit())
                    .labelStyle(.trailingIcon)
                }
            }
        }
        .padding([.top, .horizontal])
    }
    
    private var totalDuration: Duration {
        .seconds(self.secondsElapsed) + self.durationRemaining
    }
    
    private var progress: Double {
        guard self.totalDuration > .seconds(0)
        else { return 0 }
        return Double(self.secondsElapsed)
        / Double(self.totalDuration.components.seconds)
    }
}

struct MeetingTimerView: View {
    let standup: Standup
    let speakerIndex: Int
    
    var body: some View {
        Circle()
            .strokeBorder(lineWidth: 24)
            .overlay {
                VStack {
                    Group {
                        if self.speakerIndex
                            < self.standup.attendees.count {
                            Text(
                                self.standup.attendees[self.speakerIndex]
                                    .name
                            )
                        } else {
                            Text("Someone")
                        }
                    }
                    .font(.title)
                    Text("is speaking")
                    Image(systemName: "mic.fill")
                        .font(.largeTitle)
                        .padding(.top)
                }
                .foregroundStyle(self.standup.theme.accentColor)
            }
            .overlay {
                ForEach(
                    Array(self.standup.attendees.enumerated()),
                    id: \.element.id
                ) { index, attendee in
                    if index < self.speakerIndex + 1 {
                        SpeakerArc(
                            totalSpeakers: self.standup.attendees.count,
                            speakerIndex: index
                        )
                        .rotation(Angle(degrees: -90))
                        .stroke(
                            self.standup.theme.mainColor, lineWidth: 12
                        )
                    }
                }
            }
            .padding(.horizontal)
    }
}

struct MeetingFooterView: View {
    let standup: Standup
    var nextButtonTapped: () -> Void
    let speakerIndex: Int
    
    var body: some View {
        VStack {
            HStack {
                if self.speakerIndex
                    < self.standup.attendees.count - 1 {
                    Text(
            """
            Speaker \(self.speakerIndex + 1) \
            of \(self.standup.attendees.count)
            """
                    )
                } else {
                    Text("No more speakers.")
                }
                Spacer()
                Button(action: self.nextButtonTapped) {
                    Image(systemName: "forward.fill")
                }
            }
        }
        .padding([.bottom, .horizontal])
    }
}

#Preview {
    MainActor.assumeIsolated {
        NavigationStack {
            RecordMeetingView(
                store: Store(initialState: RecordMeetingFeature.State(standup: .mock)) {
                    RecordMeetingFeature()
                }
            )
        }
    }
}
