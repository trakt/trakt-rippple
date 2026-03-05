//
//  TrendingNotificationsManager.swift
//  Rippple
//
//  Created by Kevin Cador on 20/11/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Foundation

import AWSSNS

import Receiver

final class TrendingNotificationsManager {
    static let shared = TrendingNotificationsManager()

    private let disposeBag = DisposeBag()

    private var endpointARN: String? {
        return UserDefaults.standard.string(forKey: "Rippple.endpointArnForSNS")
    }

    // Settings
    var trendingMovies: Bool {
        didSet {
            UserDefaults.standard.set(trendingMovies, forKey: "TrendingNotificationsManager.trendingMovies")
            UserDefaults.standard.synchronize()
            pushInfoToAWS()
        }
    }
    var trendingShows: Bool {
        didSet {
            UserDefaults.standard.set(trendingShows, forKey: "TrendingNotificationsManager.trendingShows")
            UserDefaults.standard.synchronize()
            pushInfoToAWS()
        }
    }

    // ----

    private init() {
        trendingShows = UserDefaults.standard.bool(forKey: "TrendingNotificationsManager.trendingShows")
        trendingMovies = UserDefaults.standard.bool(forKey: "TrendingNotificationsManager.trendingMovies")
    }

    func setup() {
        pushInfoToAWS()

        onSettingsChangedReceiver.hotOnly().listen { [weak self] _ in
            guard let self = self else { return }
            guard let ARN = self.endpointARN else { return }
            if SessionManager.shared.isLoggedOut {
                if let topic = AWSConfiguration.trendingShowsTopicARN {
                    self.unsubscribe(arn: ARN, to: topic)
                }
                if let topic = AWSConfiguration.trendingMoviesTopicARN {
                    self.unsubscribe(arn: ARN, to: topic)
                }
            } else {
                self.pushInfoToAWS()
            }
        }.disposed(by: disposeBag)

        arnUpdatedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            self.pushInfoToAWS()
        }.disposed(by: disposeBag)
    }

    private func pushInfoToAWS() {
        guard let ARN = endpointARN else { return }
        if let topic = AWSConfiguration.trendingShowsTopicARN {
            if trendingShows {
                subscribe(arn: ARN, to: topic)
            } else {
                unsubscribe(arn: ARN, to: topic)
            }
        }
        if let topic = AWSConfiguration.trendingMoviesTopicARN {
            if trendingMovies {
                subscribe(arn: ARN, to: topic)
            } else {
                unsubscribe(arn: ARN, to: topic)
            }
        }
    }

    private func subscribe(arn: String, to topic: String) {
        let sns = AWSSNS.default()

        guard let subscriptionRequest = AWSSNSSubscribeInput() else { return }

        subscriptionRequest.protocols = "application"
        subscriptionRequest.topicArn = topic
        subscriptionRequest.endpoint = arn

        sns.subscribe(subscriptionRequest).continueWith(executor: AWSExecutor.mainThread(), block: { task in
            if task.error != nil {
                print("💀 AWS SNS subscribe Error: \(String(describing: task.error))")
            } else {
                print("🎉 subscribed to topic \(topic)")
            }
            return nil
        })
    }

    private func unsubscribe(arn: String, to topic: String) {
        let sns = AWSSNS.default()

        guard let subscriptionRequest = AWSSNSSubscribeInput() else { return }

        subscriptionRequest.protocols = "application"
        subscriptionRequest.topicArn = topic
        subscriptionRequest.endpoint = arn

        sns.subscribe(subscriptionRequest).continueWith(executor: AWSExecutor.mainThread(), block: { [weak self] task in
            guard let self = self else { return nil }
            if task.error != nil {
                print("💀 AWS SNS subscribe Error: \(String(describing: task.error))")
                guard let listSubscriptionsByTopic = AWSSNSListSubscriptionsByTopicInput() else { return nil }
                listSubscriptionsByTopic.topicArn = topic

                self.listSubscriptions(topic: listSubscriptionsByTopic, subscriptions: [AWSSNSSubscription](), arn: arn, unsubscibeTopic: topic)
            } else if let subscriptionArn = task.result?.subscriptionArn {
                print("🎉 subscribed to topic \(topic)")
                guard let subscriptionRequest = AWSSNSUnsubscribeInput() else { return nil }

                subscriptionRequest.subscriptionArn = subscriptionArn

                sns.unsubscribe(subscriptionRequest).continueWith(executor: AWSExecutor.mainThread(), block: { task in
                    if task.error != nil {
                        print("💀 AWS SNS unsubscribe Error: \(String(describing: task.error))")
                    } else {
                        print("🎉 unsubscribed from topic \(topic)")
                    }
                    return nil
                })
            } else {
                guard let listSubscriptionsByTopic = AWSSNSListSubscriptionsByTopicInput() else { return nil }
                listSubscriptionsByTopic.topicArn = topic

                self.listSubscriptions(topic: listSubscriptionsByTopic, subscriptions: [AWSSNSSubscription](), arn: arn, unsubscibeTopic: topic)
            }
            return nil
        })
    }

    private func listSubscriptions(topic: AWSSNSListSubscriptionsByTopicInput, subscriptions: [AWSSNSSubscription], arn: String, unsubscibeTopic: String) {
        let sns = AWSSNS.default()
        sns.listSubscriptions(byTopic: topic) { [weak self] (response, error) in
            guard let self = self else { return }
            if let error = error {
                print("💀 AWS listSubscriptions: \(String(describing: error))")
                self.unsubscribe(arn: arn, to: unsubscibeTopic, subscriptions: subscriptions)
            } else if let response = response, let newSubscriptions = response.subscriptions {
                if let nextToken = response.nextToken {
                    guard let listSubscriptionsByTopic = AWSSNSListSubscriptionsByTopicInput() else { return }
                    listSubscriptionsByTopic.topicArn = topic.topicArn
                    listSubscriptionsByTopic.nextToken = nextToken
                    self.listSubscriptions(topic: listSubscriptionsByTopic, subscriptions: subscriptions+newSubscriptions, arn: arn, unsubscibeTopic: unsubscibeTopic)
                } else {
                    self.unsubscribe(arn: arn, to: unsubscibeTopic, subscriptions: subscriptions+newSubscriptions)
                }
            }
        }
    }

    private func unsubscribe(arn: String, to topic: String, subscriptions: [AWSSNSSubscription]) {
        let sns = AWSSNS.default()
        for subscription in subscriptions where subscription.endpoint == arn {
            guard let subscriptionRequest = AWSSNSUnsubscribeInput() else { return }

            subscriptionRequest.subscriptionArn = subscription.subscriptionArn

            sns.unsubscribe(subscriptionRequest).continueWith(executor: AWSExecutor.mainThread(), block: { task in
                if task.error != nil {
                    print("💀 AWS SNS unsubscribe Error: \(String(describing: task.error))")
                } else {
                    print("🎉 unsubscribed from topic \(topic)")
                }
                return nil
            })
        }
    }
}
