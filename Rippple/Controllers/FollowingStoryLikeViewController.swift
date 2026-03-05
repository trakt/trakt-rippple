//
//  FollowingViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 11/01/2018.
//  Copyright © 2018 Trakt. All rights reserved.
//

import UIKit

import Receiver

final class FollowingStoryLikeViewController: UICollectionViewController {

    private let disposeBag = DisposeBag()

    override func viewDidLoad() {
        super.viewDidLoad()

        collectionView.allowsFocus = false
        collectionView?.register(UINib(nibName: "FollowingCollectionViewCell", bundle: nil), forCellWithReuseIdentifier: "following")

        FollowManager.shared.onFollowingChangedReceiver.listen { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.collectionView?.reloadData()
            }
        }.disposed(by: disposeBag)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let commentsViewController = segue.destination as? CommentsViewController, let user = sender as? User {
            let type = CommentsCoordinator.ListType.user(user)
            commentsViewController.coordinator = CommentsCoordinator(type: type)
        }
    }

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return FollowManager.shared.followingCount
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "following", for: indexPath) as! FollowingCollectionViewCell

        cell.user = FollowManager.shared.following(at: indexPath.row)

        return cell
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        performSegue(withIdentifier: "user", sender: FollowManager.shared.following(at: indexPath.row))
    }
}
