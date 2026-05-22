//
//  NotificationSettingsViewController.swift
//  Rippple
//
//  Created by Kevin Cador on 28/05/2020.
//  Copyright © 2020 Trakt. All rights reserved.
//

import Receiver
import UIKit

let (onNotificationsSettingsChangedTransmitter, onNotificationsSettingsChangedReceiver) = Receiver<NotificationSettingsViewController>.make(with: .hot)

final class NotificationSettingsViewController: UITableViewController {
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        print("NotificationSettingsViewController should notify to update settings")
        onNotificationsSettingsChangedTransmitter.broadcast(self)
    }

    @IBOutlet var stingerAlert: UISwitch!

    @IBOutlet var groupEpisodes: UISwitch!

    @IBOutlet var watchlistMovieReleaseSwitch: UISwitch!
    @IBOutlet var watchlistDVDMovieReleaseSwitch: UISwitch!
    @IBOutlet var watchlistShowPremiereSwitch: UISwitch!
    @IBOutlet var watchlistSeasonPremiereSwitch: UISwitch!
    @IBOutlet var watchlistEpisodeReleaseSwitch: UISwitch!

    @IBOutlet var toWatchMovieReleaseSwitch: UISwitch!
    @IBOutlet var toWatchDVDMovieReleaseSwitch: UISwitch!
    @IBOutlet var toWatchShowPremiereSwitch: UISwitch!
    @IBOutlet var toWatchSeasonPremiereSwitch: UISwitch!
    @IBOutlet var toWatchEpisodeReleaseSwitch: UISwitch!

    @IBOutlet var commentNewLikeSwitch: UISwitch!
    @IBOutlet var commentNewReplySwitch: UISwitch!
    @IBOutlet var commentNewMentionSwitch: UISwitch!

    @IBOutlet var activityFollowSwitch: UISwitch!

    @IBOutlet var trendingMoviesSwitch: UISwitch!
    @IBOutlet var trendingShowsSwitch: UISwitch!

    @IBOutlet var recommendedMoviesSwitch: UISwitch!
    @IBOutlet var recommendedShowsSwitch: UISwitch!

    @IBOutlet var anticipatedMoviesSwitch: UISwitch!
    @IBOutlet var anticipatedShowsSwitch: UISwitch!

    @IBOutlet var appUpdateSwitch: UISwitch!
    @IBOutlet var blogPostSwitch: UISwitch!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        updateSwitches()
    }

    private func updateSwitches() {
        stingerAlert.isOn = UserDefaults.standard.bool(forKey: "Stinger.alert.type")

        groupEpisodes.isOn = EpisodeNotificationsManager.shared.groupEpisodes

        watchlistMovieReleaseSwitch.isOn = MovieNotificationsManager.shared.watchlistMovieRelease
        watchlistDVDMovieReleaseSwitch.isOn = DVDMovieNotificationsManager.shared.watchlistMovieRelease
        watchlistShowPremiereSwitch.isOn = EpisodeNotificationsManager.shared.watchlistShowPremiere
        watchlistSeasonPremiereSwitch.isOn = EpisodeNotificationsManager.shared.watchlistSeasonPremiere
        watchlistEpisodeReleaseSwitch.isOn = EpisodeNotificationsManager.shared.watchlistEpisodeRelease

        toWatchMovieReleaseSwitch.isOn = MovieNotificationsManager.shared.toWatchMovieRelease
        toWatchDVDMovieReleaseSwitch.isOn = DVDMovieNotificationsManager.shared.toWatchMovieRelease
        toWatchShowPremiereSwitch.isOn = EpisodeNotificationsManager.shared.toWatchShowPremiere
        toWatchSeasonPremiereSwitch.isOn = EpisodeNotificationsManager.shared.toWatchSeasonPremiere
        toWatchEpisodeReleaseSwitch.isOn = EpisodeNotificationsManager.shared.toWatchEpisodeRelease

        commentNewLikeSwitch.isOn = ActivityNotificationsManager.shared.commentNewLikes
        commentNewReplySwitch.isOn = ActivityNotificationsManager.shared.commentNewReply
        commentNewMentionSwitch.isOn = ActivityNotificationsManager.shared.commentNewMention

        activityFollowSwitch.isOn = ActivityNotificationsManager.shared.activityNewFollower

        trendingShowsSwitch.isOn = TrendingNotificationsManager.shared.trendingShows
        trendingMoviesSwitch.isOn = TrendingNotificationsManager.shared.trendingMovies

        recommendedShowsSwitch.isOn = RecommendedNotificationsManager.shared.recommendedShows
        recommendedMoviesSwitch.isOn = RecommendedNotificationsManager.shared.recommendedMovies

        anticipatedShowsSwitch.isOn = AnticipatedNotificationsManager.shared.anticipatedShows
        anticipatedMoviesSwitch.isOn = AnticipatedNotificationsManager.shared.anticipatedMovies

        appUpdateSwitch.isOn = ManualRemoteNotificationsManager.shared.appUpdate
        blogPostSwitch.isOn = ManualRemoteNotificationsManager.shared.blogPost
    }

    @IBAction func switchValueChanged(_ sender: UISwitch) {
        if sender == groupEpisodes {
            EpisodeNotificationsManager.shared.groupEpisodes = sender.isOn
        } else if sender == watchlistMovieReleaseSwitch {
            MovieNotificationsManager.shared.watchlistMovieRelease = sender.isOn
        } else if sender == watchlistShowPremiereSwitch {
            EpisodeNotificationsManager.shared.watchlistShowPremiere = sender.isOn
        } else if sender == watchlistSeasonPremiereSwitch {
            EpisodeNotificationsManager.shared.watchlistSeasonPremiere = sender.isOn
        } else if sender == watchlistEpisodeReleaseSwitch {
            EpisodeNotificationsManager.shared.watchlistEpisodeRelease = sender.isOn
        } else if sender == toWatchMovieReleaseSwitch {
            MovieNotificationsManager.shared.toWatchMovieRelease = sender.isOn
        } else if sender == toWatchShowPremiereSwitch {
            EpisodeNotificationsManager.shared.toWatchShowPremiere = sender.isOn
        } else if sender == toWatchSeasonPremiereSwitch {
            EpisodeNotificationsManager.shared.toWatchSeasonPremiere = sender.isOn
        } else if sender == toWatchEpisodeReleaseSwitch {
            EpisodeNotificationsManager.shared.toWatchEpisodeRelease = sender.isOn
        } else if sender == commentNewLikeSwitch {
            ActivityNotificationsManager.shared.commentNewLikes = sender.isOn
        } else if sender == commentNewReplySwitch {
            ActivityNotificationsManager.shared.commentNewReply = sender.isOn
        } else if sender == commentNewMentionSwitch {
            ActivityNotificationsManager.shared.commentNewMention = sender.isOn
        } else if sender == activityFollowSwitch {
            ActivityNotificationsManager.shared.activityNewFollower = sender.isOn
        } else if sender == watchlistDVDMovieReleaseSwitch {
            DVDMovieNotificationsManager.shared.watchlistMovieRelease = sender.isOn
        } else if sender == toWatchDVDMovieReleaseSwitch {
            DVDMovieNotificationsManager.shared.toWatchMovieRelease = sender.isOn
        } else if sender == trendingMoviesSwitch {
            TrendingNotificationsManager.shared.trendingMovies = sender.isOn
        } else if sender == trendingShowsSwitch {
            TrendingNotificationsManager.shared.trendingShows = sender.isOn
        } else if sender == recommendedMoviesSwitch {
            RecommendedNotificationsManager.shared.recommendedMovies = sender.isOn
        } else if sender == recommendedShowsSwitch {
            RecommendedNotificationsManager.shared.recommendedShows = sender.isOn
        } else if sender == stingerAlert {
            UserDefaults.standard.set(sender.isOn, forKey: "Stinger.alert.type")
            UserDefaults.standard.synchronize()
        } else if sender == anticipatedShowsSwitch {
            AnticipatedNotificationsManager.shared.anticipatedShows = sender.isOn
        } else if sender == anticipatedMoviesSwitch {
            AnticipatedNotificationsManager.shared.anticipatedMovies = sender.isOn
        } else if sender == appUpdateSwitch {
            ManualRemoteNotificationsManager.shared.appUpdate = sender.isOn
        } else if sender == blogPostSwitch {
            ManualRemoteNotificationsManager.shared.blogPost = sender.isOn
        }
        updateSwitches()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
    }

    #if targetEnvironment(macCatalyst)
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 44.0
    }
    #endif
}
