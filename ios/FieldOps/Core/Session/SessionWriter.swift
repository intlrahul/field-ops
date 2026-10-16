//
//  SessionWriter.swift
//  FieldOps
//
//  Created by Rahul Singh on 15/10/26.
//

protocol SessionWriter: Sendable {
    func saveSession(_ session: Session) async
    func clearSession() async
}
