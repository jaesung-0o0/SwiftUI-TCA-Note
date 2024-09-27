//
//  SpeechClient.swift
//  Standups
//
//  Created by 이재성 on 11/7/23.
//

import Speech

/// `var` 클로져를 사용한 `struct` 로 가볍게 디자인
struct SpeechClient {
    /// `@Sendable` 이 없으면 동시성 경고가 발생. DependecyKey가 dependency 값들을 관리하기 위해 발생시키는 경고 같음
    var requestAuthorization: @Sendable () async -> SFSpeechRecognizerAuthorizationStatus
}

import Dependencies

extension SpeechClient: DependencyKey {
    static let liveValue = Self(
        requestAuthorization: {
            await withUnsafeContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(with: .success(status))
                }
            }
        }
    )
    
    /// 프리뷰를 위한 값. 프리뷰에서는 Speech 프레임워크가 동작하지 않으므로 기본값으로 `.authorized` 리턴
    static let previewValue = Self(
        requestAuthorization: { .authorized }
    )

}

extension DependencyValues {
    var speechClient: SpeechClient {
        get { self[SpeechClient.self] }
        set { self[SpeechClient.self] = newValue }
    }
}
