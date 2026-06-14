//
//  TraktAPIService+Sample.swift
//  Rippple
//
//  Created by Kevin Cador on 13/11/2017.
//  Copyright © 2017 Trakt. All rights reserved.
//

import Foundation

// MARK: - Helpers

private extension String {
    var urlEscaped: String {
        return addingPercentEncoding(withAllowedCharacters: .urlHostAllowed)!
    }

    var utf8Encoded: Data {
        return data(using: .utf8)!
    }
}

extension TraktAPIService {
    var sampleData: Data {
        switch self {
        case .token:
            return """
            {
              "access_token": "dbaf9757982a9e738f05d249b7b5b4a266b3a139049317c4909f2f263572c781",
              "token_type": "bearer",
              "expires_in": 7200,
              "refresh_token": "76ba4c5c75c96f6087f58a4de10be6c00b29ea1ddc3b2022ee2016d1363e3a7c",
              "scope": "public",
              "created_at": 1487889741
            }
            """.utf8Encoded
        case .revoke:
            return "{}".utf8Encoded
        case .watching:
            return """
            {
              "expires_at": "2014-10-23T07:09:12.000Z",
              "started_at": "2014-10-23T06:24:12.000Z",
              "action": "scrobble",
              "type": "episode",
              "episode": {
                "season": 0,
                "number": 2,
                "title": "Wedding Day",
                "ids": {
                  "trakt": 2,
                  "tvdb": 3859791,
                  "imdb": "",
                  "tmdb": 62133,
                  "tvrage": null
                }
              },
              "show": {
                "title": "Breaking Bad",
                "year": 2008,
                "ids": {
                  "trakt": 1,
                  "slug": "breaking-bad",
                  "tvdb": 81189,
                  "imdb": "tt0903747",
                  "tmdb": 1396,
                  "tvrage": 18164
                }
              }
            }
            """.utf8Encoded
        case .settings:
            return """
            {
              "user": {
                "username": "justin",
                "private": false,
                "name": "Justin Nemeth",
                "vip": true,
                "vip_ep": false,
                "ids": {
                  "slug": "justin"
                },
                "joined_at": "2010-09-25T17:49:25.000Z",
                "location": "San Diego, CA",
                "about": "Co-founder of trakt.",
                "gender": "male",
                "age": 32,
                "images": {
                  "avatar": {
                    "full": "https://secure.gravatar.com/avatar/30c2f0dfbc39e48656f40498aa871e33?r=pg&s=256"
                  }
                },
                "vip_og": true,
                "vip_years": 5
              },
              "account": {
                "timezone": "America/Los_Angeles",
                "time_24hr": false,
                "cover_image": "https://walter.trakt.tv/images/movies/000/001/545/fanarts/original/0abb604492.jpg"
              },
              "connections": {
                "facebook": true,
                "twitter": true,
                "google": true,
                "tumblr": false,
                "medium": false,
                "slack": false
              },
              "sharing_text": {
                "watching": "I'm watching [item]",
                "watched": "I just watched [item]"
              }
            }
            """.utf8Encoded
        case .comments:
            return """
                [
                    {
                        "type": "movie",
                        "movie": {
                            "title": "Batman Begins",
                            "year": 2005,
                            "ids": {
                                "trakt": 1,
                                "slug": "batman-begins-2005",
                                "imdb": "tt0372784",
                                "tmdb": 272
                            }
                        },
                        "comment": {
                            "id": 267,
                            "comment": "Great kickoff to a new Batman trilogy!",
                            "spoiler": false,
                            "review": false,
                            "parent_id": 0,
                            "created_at": "2015-04-25T00:14:57.000Z",
                            "updated_at": "2015-04-25T00:14:57.000Z",
                            "replies": 0,
                            "likes": 0,
                            "user_rating": 10,
                            "user": {
                                "username": "justin",
                                "private": false,
                                "name": "Justin N.",
                                "vip": true,
                                "vip_ep": false,
                                "ids": {
                                    "slug": "justin"
                                }
                            }
                        }
                    },
                    {
                        "type": "show",
                        "show": {
                            "title": "Breaking Bad",
                            "year": 2008,
                            "ids": {
                                "trakt": 1,
                                "slug": "breaking-bad",
                                "tvdb": 81189,
                                "imdb": "tt0903747",
                                "tmdb": 1396,
                                "tvrage": 18164
                            }
                        },
                        "comment": {
                            "id": 199,
                            "comment": "Skyler, I AM THE DANGER.",
                            "spoiler": false,
                            "review": false,
                            "parent_id": 0,
                            "created_at": "2015-02-18T06:02:30.000Z",
                            "updated_at": "2015-02-18T06:02:30.000Z",
                            "replies": 0,
                            "likes": 0,
                            "user_rating": 10,
                            "user": {
                                "username": "justin",
                                "private": false,
                                "name": "Justin N.",
                                "vip": true,
                                "vip_ep": false,
                                "ids": {
                                    "slug": "justin"
                                }
                            }
                        }
                    },
                    {
                        "type": "season",
                        "season": {
                            "number": 1,
                            "ids": {
                                "trakt": 3958,
                                "tvdb": 274431,
                                "tmdb": 60394,
                                "tvrage": 38049
                            }
                        },
                        "show": {
                            "title": "Gotham",
                            "year": 2014,
                            "ids": {
                                "trakt": 869,
                                "slug": "gotham",
                                "tvdb": 274431,
                                "imdb": "tt3749900",
                                "tmdb": 60708,
                                "tvrage": 38049
                            }
                        },
                        "comment": {
                            "id": 220,
                            "comment": "Kicking off season 1 for a new Batman show.",
                            "spoiler": false,
                            "review": false,
                            "parent_id": 0,
                            "created_at": "2015-04-21T06:53:25.000Z",
                            "updated_at": "2015-04-21T06:53:25.000Z",
                            "replies": 0,
                            "likes": 0,
                            "user_rating": 8,
                            "user": {
                                "username": "justin",
                                "private": false,
                                "name": "Justin N.",
                                "vip": true,
                                "vip_ep": false,
                                "ids": {
                                    "slug": "justin"
                                }
                            }
                        }
                    },
                    {
                        "type": "episode",
                        "episode": {
                            "season": 1,
                            "number": 1,
                            "title": "Jim Gordon",
                            "ids": {
                                "trakt": 63958,
                                "tvdb": 4768720,
                                "imdb": "tt3216414",
                                "tmdb": 975968,
                                "tvrage": 1065564827
                            }
                        },
                        "show": {
                            "title": "Gotham",
                            "year": 2014,
                            "ids": {
                                "trakt": 869,
                                "slug": "gotham",
                                "tvdb": 274431,
                                "imdb": "tt3749900",
                                "tmdb": 60708,
                                "tvrage": 38049
                            }
                        },
                        "comment": {
                            "id": 229,
                            "comment": "Is this the OC?",
                            "spoiler": false,
                            "review": false,
                            "parent_id": 0,
                            "created_at": "2015-04-21T15:42:31.000Z",
                            "updated_at": "2015-04-21T15:42:31.000Z",
                            "replies": 1,
                            "likes": 0,
                            "user_rating": 7,
                            "user": {
                                "username": "justin",
                                "private": false,
                                "name": "Justin N.",
                                "vip": true,
                                "vip_ep": false,
                                "ids": {
                                    "slug": "justin"
                                }
                            }
                        }
                    },
                    {
                        "type": "list",
                        "list": {
                            "name": "Star Wars",
                            "description": "The complete Star Wars saga!",
                            "privacy": "public",
                            "display_numbers": false,
                            "allow_comments": true,
                            "updated_at": "2015-04-22T22:01:39.000Z",
                            "item_count": 8,
                            "comment_count": 0,
                            "likes": 0,
                            "ids": {
                                "trakt": 51,
                                "slug": "star-wars"
                            }
                        },
                        "comment": {
                            "id": 268,
                            "comment": "May the 4th be with you!",
                            "spoiler": false,
                            "review": false,
                            "parent_id": 0,
                            "created_at": "2014-12-08T17:34:51.000Z",
                            "updated_at": "2014-12-08T17:34:51.000Z",
                            "replies": 0,
                            "likes": 0,
                            "user_rating": null,
                            "user": {
                                "username": "justin",
                                "private": false,
                                "name": "Justin N.",
                                "vip": true,
                                "vip_ep": false,
                                "ids": {
                                    "slug": "justin"
                                }
                            }
                        }
                    }
                    ]
            """.utf8Encoded
        case .movieSocial, .showSocial, .seasonSocial, .episodeSocial:
            return """
            [
                {
                    "followed_at": "2025-01-04T18:22:10.000Z",
                    "user": {
                        "username": "justin",
                        "private": false,
                        "name": "Justin N.",
                        "vip": true,
                        "vip_ep": false,
                        "ids": {
                            "slug": "justin",
                            "trakt": 1
                        }
                    },
                    "watched": {
                        "plays": 2,
                        "last_watched_at": "2026-06-01T20:15:00.000Z",
                        "last_updated_at": "2026-06-01T20:16:00.000Z",
                        "rating": {
                            "rating": 8,
                            "rated_at": "2026-06-01T20:20:00.000Z"
                        },
                        "comment": {
                            "ids": {
                                "trakt": 98765
                            },
                            "comment": "Loved this.",
                            "spoiler": false,
                            "review": false,
                            "created_at": "2026-06-01T20:25:00.000Z",
                            "updated_at": "2026-06-01T20:25:00.000Z"
                        }
                    },
                    "watchlisted": {
                        "listed_at": "2026-05-20T12:00:00.000Z"
                    }
                }
            ]
            """.utf8Encoded
        case .history:
            return """
            [
                {
                    "id": 1982346,
                    "watched_at": "2014-03-31T09:28:53.000Z",
                    "action": "scrobble",
                    "type": "movie",
                    "movie": {
                        "title": "The Dark Knight",
                        "year": 2008,
                        "ids": {
                            "trakt": 4,
                            "slug": "the-dark-knight-2008",
                            "imdb": "tt0468569",
                            "tmdb": 155
                        }
                    }
                },
                {
                    "id": 1982347,
                    "watched_at": "2014-02-31T09:28:53.000Z",
                    "action": "checkin",
                    "type": "episode",
                    "episode": {
                        "season": 2,
                        "number": 1,
                        "title": "Pawnee Zoo",
                        "ids": {
                            "trakt": 251,
                            "tvdb": 797571,
                            "imdb": null,
                            "tmdb": 397629,
                            "tvrage": null
                        }
                    },
                    "show": {
                        "title": "Parks and Recreation",
                        "year": 2009,
                        "ids": {
                            "trakt": 4,
                            "slug": "parks-and-recreation",
                            "tvdb": 84912,
                            "imdb": "tt1266020",
                            "tmdb": 8592,
                            "tvrage": 21686
                        }
                    }
                },
                {
                    "id": 1982348,
                    "watched_at": "2013-06-15T05:54:27.000Z",
                    "action": "watch",
                    "type": "movie",
                    "movie": {
                        "title": "TRON: Legacy",
                        "year": 2010,
                        "ids": {
                            "trakt": 1,
                            "slug": "tron-legacy-2010",
                            "imdb": "tt1104001",
                            "tmdb": 20526
                        }
                    }
                }
            ]
            """.utf8Encoded
        default:
            return "{}".utf8Encoded
        }
    }
}
