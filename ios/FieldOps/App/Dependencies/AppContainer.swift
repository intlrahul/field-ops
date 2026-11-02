//
//  AppContainer.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

import Foundation

@MainActor
final class AppContainer {
    let apiClient: any APIClient
    let inspectionRepository: any InspectionRepository
    let authFactory: AuthFactory
    let sessionStore: any SessionProvider & SessionWriter

    init(baseURL: URL) {

        let storage = KeychainStorage(
            service: "com.yourcompany.FieldOps"
        )

        let persistence = DefaultSessionPersistence(
            storage: storage
        )

        sessionStore = SessionStore(
            persistence: persistence
        )

        apiClient = AlamofireAPIClient(
            baseURL: baseURL,
            accessTokenProvider: sessionStore
        )

        inspectionRepository = RemoteInspectionRepository(
            apiClient: apiClient
        )

        authFactory = AuthFactory(
            apiClient: apiClient,
            sessionProvider: sessionStore,
            sessionWriter: sessionStore
        )
    }
}
