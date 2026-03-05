//
//  ExperimentalViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 15/05/2021.
//  Copyright © 2021 Trakt. All rights reserved.
//

import UIKit

import Receiver

let (sentimentEnabledTransmitter, sentimentEnabledReceiver) = Receiver<Bool>.make(with: .hot)

final class ExperimentalViewController: UITableViewController {

    private let disposeBag = DisposeBag()

    private let coreMLBuilder = CoreMLBuilder()

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return "Features in this section are subject to big changes, may not be stable and can even be completly removed in future versions."
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "Experimental"
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        #if DEBUG
        return 2
        #else
        return 1
        #endif
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = super.tableView(tableView, cellForRowAt: indexPath)

        if indexPath.row == 0 {
            cell.textLabel?.text = "Sentiment Analysis on Comments"
            if UserDefaults.standard.bool(forKey: "Experimental.sentiment") == true {
                cell.detailTextLabel?.text = "Enabled"
            } else {
                cell.detailTextLabel?.text = "Disabled"
            }
        } else {
            cell.textLabel?.text = "Build CoreML"
            cell.detailTextLabel?.text = nil
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.row == 0 {
            let alertController = UIAlertController(title: "Sentiment Analysis on Comments",
                                                    message: "Add a sentiment indicator on comments. This feature rely on a basic Natural Language Processor that can be realy wrong sometimes!",
                                                    preferredStyle: .actionSheet)

            let cancel = UIAlertAction(title: "Cancel", style: .cancel)
            alertController.addAction(cancel)

            if UserDefaults.standard.bool(forKey: "Experimental.sentiment") == true {
                let disable = UIAlertAction(title: "Disable Sentiment Analysis", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    UserDefaults.standard.setValue(false, forKey: "Experimental.sentiment")
                    UserDefaults.standard.synchronize()
                    sentimentEnabledTransmitter.broadcast(false)
                    self.tableView.reloadData()
                }
                alertController.addAction(disable)
            } else {
                let enable = UIAlertAction(title: "Enable Sentiment Analysis", style: .default) { [weak self] _ in
                    guard let self = self else { return }
                    UserDefaults.standard.setValue(true, forKey: "Experimental.sentiment")
                    UserDefaults.standard.synchronize()
                    sentimentEnabledTransmitter.broadcast(true)
                    self.tableView.reloadData()
                }
                alertController.addAction(enable)
            }

            alertController.popoverPresentationController?.sourceView = tableView.cellForRow(at: indexPath)

            present(alertController, animated: true)
        } else {
            coreMLBuilder.startBuildingCoreMLModel()
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }

    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 54.0
    }
    #endif

    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 44
    }
    #endif
}

private final class CoreMLBuilder {

    private let operationQueue: OperationQueue = {
        var queue = OperationQueue()
        queue.name = "CoreML building operation queue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
      return queue
    }()

    // Private
    private var followers = [User]() {
        didSet {
            print("\(followers.count) Follower received")

            var fileURL: URL
            let fileManager = FileManager.default
            do {
                let path = try fileManager.url(for: .documentDirectory,
                                               in: .allDomainsMask,
                                               appropriateFor: nil,
                                               create: true)
                fileURL = path.appendingPathComponent("CSVData.csv")
                try "user,item,traktid,rating\n".write(to: fileURL,
                                                       atomically: true,
                                                       encoding: .utf8)
                print("CSV file created at: \(path)")
            } catch {
                print("Error creating CSV file: \(error)")
                return
            }

            var total = 0.0
            var processed = 0.0
            for user in followers where user.isPrivate == false {
                let operation = PutRatingsInCSVFileOperation(user: user, in: fileURL)
                operationQueue.addOperation(operation)
                total += 1
                operation.completionBlock = {
                    processed += 1
                    print("Operation progress t = \(total), processed = \(processed)")
                }
            }
        }
    }

    func startBuildingCoreMLModel() {
        fetchFollowers()
    }

    private func fetchFollowers() {
        if SessionManager.shared.isLoggedOut {
            return
        }

        print("Fetching Followers...")

        TraktAPIProvider.provider.request(.followers(slug: "justin"), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let users = try response.map([Follow].self, using: TraktAPIProvider.decoder).map { $0.user }.removingDuplicates()

                    self.followers = users
                } catch {
                    print("/followers request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("/followers request failure \(error)")
            }
        }
    }
}

private final class PutRatingsInCSVFileOperation: Operation, @unchecked Sendable {

    private let dispatchGroup = DispatchGroup()

    fileprivate var user: User
    fileprivate var fileURL: URL

    init(user: User, in fileURL: URL) {
        self.user = user
        self.fileURL = fileURL
    }

    override func cancel() {
        super.cancel()

        state = .isFinished
    }

    private enum State: String {
        case isReady
        case isExecuting
        case isFinished
    }

    private var state: State = .isReady {
        willSet(newValue) {
            willChangeValue(forKey: state.rawValue)
            willChangeValue(forKey: newValue.rawValue)
        }
        didSet {
            didChangeValue(forKey: oldValue.rawValue)
            didChangeValue(forKey: state.rawValue)
        }
    }

    override var isAsynchronous: Bool { true }
    override var isExecuting: Bool { state == .isExecuting }
    override var isFinished: Bool {
        if isCancelled && state != .isExecuting { return true }
        return state == .isFinished
    }

    override func start() {
        if isCancelled { return }

        state = .isExecuting

        dispatchGroup.enter()
        print("Begining fetching ratings for \(user.slug)")
        TraktAPIProvider.provider.request(.rated(slug: user.slug, type: .movies, extended: nil), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
            guard let self = self else { return }

            defer {
                self.dispatchGroup.leave()
            }

            switch result {
            case let .success(moyaResponse):
                do {
                    let response = try moyaResponse.filterSuccessfulStatusCodes()

                    let ratedItems = try response.map([RatedItem].self, using: TraktAPIProvider.decoder)

                    self.dispatchGroup.enter()
                    print("Begining watched for \(self.user.slug)")
                    TraktAPIProvider.provider.request(.watched(slug: self.user.slug, type: .movies, extended: .noseasons), callbackQueue: DispatchQueue.global(qos: .utility)) { [weak self] result in
                        guard let self = self else { return }

                        defer {
                            self.dispatchGroup.leave()
                        }

                        switch result {
                        case let .success(moyaResponse):
                            do {
                                let response = try moyaResponse.filterSuccessfulStatusCodes()

                                let watchedItems = try response.map([WatchedItem].self, using: TraktAPIProvider.decoder)

                                var dataString = ""
                                var movies = [Movie]()
                                for ratedItem in ratedItems {
                                    guard let movie = ratedItem.movie else { continue }
                                    movies.append(movie)
                                    dataString.append("\"\(self.user.slug)\",\"\(movie.title.slugify())\",\(movie.identifiers.trakt!),\(ratedItem.rating)\n")
                                }
                                for watchedItem in watchedItems {
                                    guard let movie = watchedItem.movie else { continue }
                                    if movies.contains(movie) { continue }
                                    dataString.append("\"\(self.user.slug)\",\"\(movie.title.slugify())\",\(movie.identifiers.trakt!),5\n")
                                }

                                if !dataString.isEmpty, let fileHandle = FileHandle(forWritingAtPath: self.fileURL.path) {
                                    fileHandle.seekToEndOfFile()
                                    fileHandle.write(dataString.data(using: .utf8)!)
                                    fileHandle.closeFile()
                                }
                            } catch {
                                print("/watched request JSON mapping failed! \(error)")
                            }
                        case let .failure(error):
                            print("/watched request failure \(error)")
                        }
                    }
                } catch {
                    print("/rated request JSON mapping failed! \(error)")
                }
            case let .failure(error):
                print("/rated request failure \(error)")
            }
        }

        dispatchGroup.notify(queue: .global(qos: .utility)) { [weak self] in
            guard let self = self else { return }
            if self.isCancelled { return }

            print("Finished fetching ratings and watched for \(self.user.slug)")

            self.state = .isFinished
        }
    }
}
