# SwiftUI-TCA-Note
The Composable Architecture 공부 노트 (SwiftUI)

<img width="75%" alt="Screenshot 2023-09-01 at 2 00 58 AM" src="https://github.com/jaesung-0o0/SwiftUI-TCA-Note/assets/53814741/e308fd18-c2c9-4a2e-9628-2f1874a3f94a">

# EPISODE. The Basics

## Testing

### MainActor
```swift
@MainActor
final class TheBasicsTests: XCTestCase
```
XCTestCase 클래스에 MainActor 속성 추가하여 테스트들이 메인쓰레드에서 돌아가는 것을 보장.

### TestStore
```swift
let store = TestStore(initialState: CounterFeature.State()) {
    CounterFeature()
}
```

### `store.send(_:)`
```swift
await store.send(.incrementButtonTapped) {
    // $0: in-out piece of state. 액션 보내지기 전의 상태.
    // 액션 전의 State의 값을 액션 후 기대되는 State에 맞춰 값으로 세팅
    $0.count = 1
}
```

## Dependencies

### Task & Clock

```swift
Task.sleep(for: .second(1))
```
Task 를 쓰면 테스팅할때 아래와 같은 코드 작성시 sleep 시간만큼 정직하게 기다려야해서 테스트 시간이 오래 걸림.
```swift
Task.sleep(for: .second(1))

await store.receive(.timerTicked) {
    $0.count = 1
}

Task.sleep(for: .second(1))

await store.receive(.timerTicked) {
    $0.count = 1
}
```
이를 개선하기 위해 TCA 에서 제공하는 clock을 사용
```swift
// Reducer
@Dependency(\.continuousClock) var clock

var body: some ReducerOf<Self> { state, action in
    // ...
    self.clock.timer(interval: .seconds(1))
}
```
테스트에서는 `advance(by:)` 를 사용해서 시간을 앞당기는 효과를 줄 수 있음. 타임워프
```swift
let clock = TestClock()

let store = TestStore(initialState: CounterFeature.State()) {
    CounterFeature()
} withDependencies: {
    $0.continuousClock = clock
}

await clock.advance(by: .seconds(1))
```
위의 Task 를 사용한 코드를 아래와 같이 바꾸면 순식간에 테스트가 완료
```swift
await clock.advance(by: .seconds(1))

await store.receive(.timerTicked) {
    $0.count = 1
}

await clock.advance(by: .seconds(1))

await store.receive(.timerTicked) {
    $0.count = 1
}
```

### Testing Error Case

```swift
let store = TestStore(initialState: CounterFeature.State()) {
    CounterFeature()
} withDependencies: {
    /// 테스트용 API Client  디펜던시
    $0.numberFact.fetch = { _ in
        struct SomeError: Error { }
        throw SomeError()
    }
}

/// 실패가 예상된다고 알리고  실패가 발생하면 테스트 성공 (강제로 통과)
XCTExpectFailure()

await store.send(.getFactButtonTapped) {
    /// 리듀서에서는 에러 처리 안하고 있음
    /// 따라서 액션 보낼 때 아무 사이드 이펙트를 받지 못함
    ///
    /// 테스트는 통과 -> isLoadingFact 이 계속 true -> 무한 로딩
    $0.isLoadingFact = true
}
```

### UUID

```swift
// Reducer
@Dependency(\.uuid) var uuid

var body: some ReducerOf<Self> { state, action in
    // ...
    let id = self.uuid()
}
```
```swift
// Testing method
let store = TestStore(
    initialState: StandupFormFeature.State(
        standup: Standup(
        id: UUID(),
        attendees: [
            Attendee(id: UUID())
        ]
    )
),
reducer: { StandupFormFeature() },
withDependencies: {
    /// `UUID(0)` 부터 시작해서 증가하는 방식으로 uuid 생성
    $0.uuid = .incrementing
    }
)
```

### 디펜던시 만들기
```swift
/// 숫자에 대한 재밌는 사실을 가져오는 API Client
struct NumberFactClient {
    var fetch: @Sendable (Int) async throws -> String
}

extension NumberFactClient: DependencyKey {
    static var liveValue = Self { number in
        let (data, _) = try await URLSession.shared.data(
            from: URL(
                string: "http://www.numbersapi.com/\(number)"
            )!
        )
        return String(decoding: data, as: UTF8.self)
    }
}

extension DependencyValues {
    var numberFact: NumberFactClient {
        get { self[NumberFactClient.self] }
        set { self[NumberFactClient.self] = newValue }
    }
}
```

# EPISODE. Standups

## Binding

### Basics
```swift
// State
@BindingState var standup: Standup
```
```swift
// Action
case binding(BindingAction<State>)
```
```swift
// Reducer
var body: some ReducerOf<Self> {
    BindingReducer() // 먼저 실행. 들어온 Binding action 을 다루고 BindingState 값을 업데이트

    Reduce { state, action in ... }
}
```

```swift
// View
let store: StoreOf<StandupFeature>

var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
        TextField("제목", text: viewStore.$standup.title)
    }
}
```
Pointfree 에서 지향하는 모습 (`WithViewStore` 가 사라지고 `Store` 를 `@State` 속성래퍼와 함께 사용)
```swift
// View (To-Be)
@State var store: StoreOf<StandupFeature>
Var body: some View {
    TextField("제목", text: $store.standup.title)
}
```

### Focus
```swift
// State
@BindingState var focus: Field?

enum Field: Hashable {
    case attendee(Attendee.ID)
    case title
}
```
```swift
// Action
case binding(BindingAction<State>)
```
```swift
// Reducer
var body: some ReducerOf<Self> {
    BindingReducer() // 먼저 실행. 들어온 Binding action 을 다루고 BindingState 값을 업데이트

    Reduce { state, action in
        switch action {
        case .addAttendeeButtonTapped:
            // append new attendee to `state.standup` and then...
            state.focus = .attendee(newAttend.id)
        }
    }
}
```

```swift
// View
let store: StoreOf<StandupFeature>

/// 1️⃣ 뷰에`.bind(_:to:)` 를 통해 store의 focus 를 self.focus 에 바인딩
@FocusState var focus: StandupFeature.State.Field?

var body: some View {
    WithViewStore(self.store, observe: { $0 }) { viewStore in
        TextField("제목", text: viewStore.$standup.title)
            .focused(self.$focus, equals: .title) // 3️⃣ `focus` 값이 `.title` 이면 해당 텍스트필드에 초점 맞추기
            .bind(viewStore.$focus, to: self.$focus) // 2️⃣
    }
}
```


# EPISODE. Navigation

## Presentation

```swift
// State

@PresentationState var addStandup: StandupFormFeature.State?
```

```swift
// Action
case addStandup(PresentationAction<StandupFormFeature.Action>)
```
`PresentationAction` 에는 2가지 작업 케이스가 있음.
- `dismiss`
- `presented`

```swift
// Reducer

Reduce { state, action in
    switch action {
        case .addButtonTapped:
            // 네비게이션 활성화
            state.addStandup = StandupFormFeature.State(standup: Standup.empty)
            return .none
            
        case .saveStandupButtonTapped:
            // 부모와 통신
            guard let standup = state.addStateup?.standup else {
                return .none
            }
            state.standups.apped(standup)
            
            // 네비게이션 비활성화
            state.addStandup = nil
            return .none
        }
    }
    .ifLet(\.$addStandup, action: /Action.addStandup) { // keyPath, casePath
        StandupFormFeature()
    }
}
```

```swift
// View

/// `sheet(store:content:)` 사용
.sheet(
    /// `scope` 을 사용하여 `Store`의 범위를 **특정 부분에만 초점을** 맞출 수 있음
    store: self.store.scope(
        state: \.$addStandup,       // keyPath
        action: { .addStandup($0) } // closure
    )
) { store in
    StandupForm(store: store)
} 
/// **스와이프로 dismiss**하면 자동으로 `state.addStandup = nil` 이 됨
```

### scope

`store.scope` 을 사용하여 `Store`의 범위를 **특정 부분에만 초점을** 맞출 수 있음

### ifLet

부모-자식 간의 Feature를 통합하여 서로간의 통신이 가능.

예를 들어 부모가 언제 "참석자 추가" 버튼을 눌렀는지 알고 싶다면 아래와 같이 하면됨
```swift
case .addStandup(.presented(.addAttendeeButtonTapped)):
    // do something
```

## 비포괄 테스트

### 포괄 방식 테스트
```swift
// 저장버튼 누른 경우
await store.send(.saveStandupButtonTapped) {
    $0.addStandup = nil
    $0.standups[0] = Standup(
        id: UUID(0),
        attendees: [Attendee(id: UUID(1))],
        title: "Point-Free Morning Sync"
    )
}
```
포괄 방식 테스트는 $0 에 업데이트한 값이 액션 후 상태값과 전부 일치해야 테스트가 통과.
👉 때로는 모든 데이터를 다보는 것이 아닌 특정 값의 업데이트만 확인하고 싶을 때가 있음
👉 이 때 필요한게 비포괄 테스트

### 비포괄 방식 테스트
모든 댠계를 거치면 마지막에 `Standup` 객체가 컬렉션에 추가되는지만 확인하고 싶을 때(모든 작동 검증 없이 특정 결과만 확인하고 싶은 경우), 비포괄 테스트를 사용한다.

비포괄적 테스트 모드를 하려면 `TestStore` 객체 생성 후 다음 코드를 추가한다.
```swift
store.exhaustivity = .off
```
그러면 `send` 의 클로져의 argument (`$0`) 가 액션 전의 상태가 아닌 **액션 후의 상태**를 의미

> INFO:
> 
> 만약 특정 결과만 확인하고 싶더라도 중간에 체크 안된 작동을 메세지로 받고 싶다면
> `store.exhaustivity = .off(showSkippedAssertions: true)`

```swift
await store.send(.saveStandupButtonTapped) {
-   $0.addStandup = nil // 🔴 제거해도 테스트 통과
    $0.standups[0] = Standup(
        id: UUID(0),
        attendees: [Attendee(id: UUID(1))],
        title: "Point-Free Morning Sync"
    )
}
```

## 네비게이션 방식 (Navigation Styles)

### 트리 기반 네비게이션 (Tree-based navigation)
네비게이션 state를 옵셔널로 모델링 하는 것
- nil 이면, 해당 feature로 네비게이트 하지 않음을 나타냄
- 값이 존재하면, 네비게이션을 활성화함을 나타냄.
sheet 에서 사용하는 방식. 

### 스택 기반 네비게이션 (Stack-based navigation)
state의 1차원 배열로 네비게이션 스택을 모델링 하는 것
드릴 다운 네비게이션을 위한 방식으로. 스택에 값을 추가하는 방식에 대응.


# EPISODE. Stacks

아래는 순수 SwiftUI 에서의 네비게이션 스택.

```swift
NavigationStack(path: Binding<_>, root: ()-> _) {
    ...
}
```
이걸 TCA 로 다루는 법을 배우는 에피소드

## 네비게이션 스택

### 근본: App Feature

네비게이션 스택에서 띄워질 모든 feature들을 통합시킴
정리해보자면
- StandupsListFeature 은 가장 root 이기 때문에 pop 될 일이 없음
- StandupDetailView는 이번에 드릴 다운 네비게이션을 할 대상
- 그리고 회의 녹화 기능 같은 앞으로 배울 기능도 드릴 다운 대상  

```swift
struct AppFeature: Reducer {

}
```

**State**
```swift
// AppFeature.struct
struct State {
    var standupsList = StandupsListFeature.State() // 항상 root 로 갖고 있어서 절대로 팝 될 일이 없음
}
```
**Action**
```swift
enum Action {
    case standupsList(StandupsListFeature.Action)
}
```
**Reducer/Body**
```swift
Reduce { state, action in
    switch action {
    case .standupsList:
        return .none
    }
}
```
`StandupsListFeature` 리듀서를 `AppFeature/body` 에 compose 할 방법을 이제 고민

👉 이때 사용하는 것이 `Scope`

`Scope` 은 부모로 부터 도메인 일부를 떼어내서 자식 리듀서를 실행

```swift
var body: some ReducerOf<Self> {
    Scope(state: \.standupsList, action: /Action.standupsList) { 
        StandupsListFeature() // 자식 리듀서 
    }
    
    Reduce { ... }
}
```
액션이 들어오면 `Scope` 의 child 리듀서에서 먼저 돌아가고 그 다음에 `AppFeature` 코어 로직인 `Reduce` 가 실행됨

**Store**
```swift
// AppView.struct
let store: StoreOf<AppFeature> // 1️⃣ full parent domain of app feature

var body: some View {
    NavigationStack {
        StandupsListView(
            store: self.store.scope( // 2️⃣ to pluck out the domain we're interested in, scope on the store
                state: \.standupsList, 
                action: { .standupsList($0) 
            )
        )
    }
}
```

### 푸시

푸시를 위한 TCA 도구가 있음.

**State**
현재 어떤 feature가 스택에서 돌아가는지를 나타내기 위해 `StackState` 라는 것을 사용한 collection 변수를 선언
```swift
struct State {
    var path = StackState<Path.State>()
    // ...
}
```
**Action**
```swift
enum Action {
    case path(StackAction<Path.state, Path.Action>)
    // ...
}
```
`StackAction` 는 PresentationAction 과 동일
- `element(id:action:)` 
    - 다루고자 하는 스택 요소의 `id` 와 `action` 을 사용해서 스택의 자식 요소에 어떤 일이 일어나는지 나타낼 수 있음
- `popFrom(id:)`
    - 어떤 `id` 로 부터 팝
- `push(id:state)`

**Reducer/body**
```swift
Reduce { state, action in
    switch action {
    case .path: // 1️⃣
        return .none
    }
}
.forEach(\.path, action: /Action.path) { // 2️⃣
    Path()
}
```
- 1️⃣ `.path` 케이스에서 `.popFrom(id:)` 같은 액션을 전달해서 스택 요소를 팝할 수 있음
- 2️⃣ `.forEach(_:action:destination:)`
    - `destination`에는 모든 destination 을 캡슐화한 리듀서를 사용
    - `$` 기호를 안쓰는 건 `StackState`가 프로퍼티 래퍼가 아니기 때문

**Store**
```swift
var body: some View {
    NavigationStackStore(
        self.store.scope(state: \.path, action: { .path($0) })  // 1️⃣
    ) {
        // 2️⃣ root
        StandupsListView(...)
    } destination: { state in // 3️⃣
        switch state {
        case .detail:
            CaseLet(    // 4️⃣
                /AppFeature.Path.State.detail,
                action: AppFeature.Path.Action.detail,
                then: { StandupDetailView(store: $0) }
            )
        }
    }
}
```
- NavigationStackStore 에서는 3가지를 다룸
    - 1️⃣ `store`: 네비게이션을 돌리기 위한 스택의 상태와 액션에 맞춘 store를 전달. 즉 `store.scope` 사용
    - 2️⃣ `root`: root 뷰
    - 3️⃣ `destination`: 스택에 푸시될 수 있는 모든 뷰의 destination
        - 4️⃣ destination 뷰에 store 를 전달할 때는 `scope` 보다는 `CaseLet` 을 사용할 것. `scope` 은 복잡하기 때문

**NavigationStackStore/destination**
```swift
// 미래의 TCA가 가질 모습: CaseLet 제거 하고 scope 사용하기
destination: { store in
    switch store.state {
    case .detail:
        if let store = store.scope(state: \.detail, action: { .detail($0) }) {
            StandupDetailView(store: store)
        }
    }
}
```

스택은 많은 스크린 타입을 다룰 수 있다. 그래야 Detail 스크린 말고도, 녹화 스크린, 지난 미팅 기록 스크린 으로도 드릴 다운 할 수 있다.

따라서 다양한 위치들을 enum 을 사용해서 모델링 해야하고 각 스택의 대상을 단일 기능으로 패키징 하기 위해 `Path` 라는 새로운 리듀서를 정의.

즉, Path 를 위한 State가 enum 인 리듀서를 생성
```swift
struct Path: Reducer {
    enum State {
        case detail(StandupDetailFeature.State)
        // 그 외의 destination
    }
    
    enum Action {
        case detail(StandupDetailFeature.Action)
    }
    
    var body: some ReducerOf<Self> {
        // Scope 을 사용해서 모든 destination 의 리듀서를 compose 해야한다.
        Scope(state: /State.detail, action: /Action.detail) {
            StandupDetailFeature()
        }
    }
}
```
앞으로 푸시해야할 새 feature가 생기면 `Path` 리듀서의 `State` 와 `Action` 에 `case` 를 추가하고 `body` 에 `Scope` 를 추가.
```swift
// Path.State.enum
+   case recordMeeting(RecordMeetingFeature.State)
```
```swift
// Path.Action.enum
+   case recordMeeting(RecordMeetingFeature.State)
```
```swift
// Path/body
+   Scope(state: /State.recordMeeting, action: /Action.recordMeeting) {
        RecordMeetingFeature()
    }
}
```

**푸시 액션**
```swift
// StandupsListView/body

NavigationLink(
    state: AppFeature.Path.State.detail(
        StandupDetailFeature.State(standup: standup)
    )
) {
    CardView(standup: standup)
}
```
`NavigationLink(state:)` 라는 새로운 생성자를 사용해서 `AppFeature.Path` 스택 상태를 `detail` 로 변경할 수 있음
