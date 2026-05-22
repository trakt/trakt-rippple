//
//  NotesListViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 27/09/2023.
//  Copyright © 2023 Trakt. All rights reserved.
//

import NVActivityIndicatorView
import Receiver
import UIKit

final class NotesListViewController: UITableViewController {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    private let disposeBag = DisposeBag()

    @IBOutlet var emptyView: UIView!

    private enum Section: Hashable {
        case empty
        case content
    }

    private enum Wrapper: Hashable {
        case empty
        case loading
        case notes(NoteItem)
    }

    private class NotesDiffibleDataSource: UITableViewDiffableDataSource<Section, Wrapper> {}

    private lazy var dataSource = NotesDiffibleDataSource(tableView: tableView) { [weak self] tableView, _, item in
        guard let self = self else { return nil }

        switch item {
        case .notes(let noteItem):
            let cell = tableView.dequeueReusableCell(withIdentifier: "notes") as! NotesTableViewCell
            cell.noteItem = noteItem
            cell.delegate = self
            return cell
        case .empty:
            let cell = tableView.dequeueReusableCell(withIdentifier: "empty") as! EmptyTableViewCell
            cell.emoji.text = "🫙"
            cell.title.text = "No Notes"
            cell.subtitle.text = "Add Notes to movies, TV shows, episodes, seasons, collection, ratings and history items."
            cell.body.text = "Then come back to see them here..."
            cell.action.isHidden = true
            return cell
        case .loading:
            return tableView.dequeueReusableCell(withIdentifier: "loading") as! LoadingIndicatorTableViewCell
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.allowsFocus = false
        tableView.register(UINib(nibName: "NotesTableViewCell", bundle: nil), forCellReuseIdentifier: "notes")
        tableView.register(UINib(nibName: "LoadingIndicatorTableViewCell", bundle: nil), forCellReuseIdentifier: "loading")
        tableView.register(UINib(nibName: "EmptyTableViewCell", bundle: nil), forCellReuseIdentifier: "empty")
        tableView.dataSource = dataSource
        tableView.delegate = self
        tableView.separatorStyle = .none

        dataSource.defaultRowAnimation = .none

        var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
        snapshot.appendSections([.empty])
        snapshot.appendItems([.loading])
        dataSource.apply(snapshot, animatingDifferences: false)

        onNotesChangedReceiver.listen { [weak self] noteItems in
            guard let self = self else { return }
            refreshControl?.endRefreshing()
            var snapshot = NSDiffableDataSourceSnapshot<Section, Wrapper>()
            if noteItems.isEmpty {
                snapshot.appendSections([.empty])
                snapshot.appendItems([.empty])
            } else {
                snapshot.appendSections([.content])
                snapshot.appendItems(noteItems.map { .notes($0) })
            }
            dataSource.apply(snapshot, animatingDifferences: false)
        }.disposed(by: disposeBag)

        #if !targetEnvironment(macCatalyst)
        refreshControl = UIRefreshControl()
        #endif
        refreshControl?.addTarget(self, action: #selector(refresh(_:)), for: .valueChanged)
    }

    @objc func refresh(_ sender: Any) {
        NotesManager.shared.refresh()
    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)

        guard let item = dataSource.itemIdentifier(for: indexPath) else { return }
        switch item {
        case .notes(let noteItem):
            NotesManager.shared.showNotes(for: noteItem)
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let item = dataSource.itemIdentifier(for: indexPath) else { return nil }
        switch item {
        case .notes(let noteItem):
            let delete = UIContextualAction(style: .normal,
                                            title: "Delete") { _, _, boolValue in
                self.deleteNote(noteItem: noteItem)
                boolValue(true)
            }
            delete.image = UIImage(systemName: "minus.circle.fill")
            delete.backgroundColor = .systemRed

            let configuration = UISwipeActionsConfiguration(actions: [delete])
            configuration.performsFirstActionWithFullSwipe = false

            return configuration
        default:
            return nil
        }
    }

    private func deleteNote(noteItem: NoteItem) {
        guard let window = view.window else { return }
        window.isUserInteractionEnabled = false

        SwiftMessages.show(message: "Deleting Notes...", style: .loading)

        TraktAPIProvider.provider.request(.deleteNotes(id: noteItem.note.identifier),
                                          callbackQueue: .global(qos: .userInitiated)) { result in
            switch result {
            case .success(let moyaResponse):
                do {
                    _ = try moyaResponse.filterSuccessfulStatusCodes()
                    NotesManager.shared.refresh()
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "📝 Notes deleted")
                        window.isUserInteractionEnabled = true
                    }
                } catch {
                    NotesManager.shared.refresh()
                    DispatchQueue.main.async {
                        SwiftMessages.show(message: "😓 Error deleting notes", style: .error(error))
                        window.isUserInteractionEnabled = true
                    }
                }
            case .failure(let error):
                print("Notes deleting failed! \(error)")
                NotesManager.shared.refresh()
                DispatchQueue.main.async {
                    SwiftMessages.show(message: "😓 Error deleting notes", style: .error(error))
                    window.isUserInteractionEnabled = true
                }
            }
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let mediaViewController = segue.destination as? MediaViewController {
            if let media = sender as? MediaModel {
                mediaViewController.media = media
            } else {
                fatalError()
            }
        }
    }

    @IBSegueAction
    func makePeopleViewController(coder: NSCoder, sender: Any?) -> PeopleViewController? {
        if let person = sender as? Person {
            return PeopleViewController(coder: coder,
                                        cast: nil,
                                        job: nil,
                                        person: person)
        } else {
            return nil
        }
    }
}

extension NotesListViewController: NotesTableViewCellDelegate {
    func cell(_ cell: NotesTableViewCell, action: NotesTableViewCell.Action) {
        switch action {
        case .media(let mediaModel):
            switch mediaModel {
            case .movie, .show, .episode, .season:
                performSegue(withIdentifier: "media", sender: mediaModel)
            case .list:
                fatalError()
            case .showProgress:
                fatalError()
            }

        case .person(let person):
            performSegue(withIdentifier: "person", sender: person)
        }
    }
}
