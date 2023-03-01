def database(path) 
    db = SQLite3::Database.new('db/main.db')
	db.results_as_hash = true
    return db
end


def users(db, user_ids)
    users = []
    user_ids.each do | user_id |
        sought_user = db.execute("SELECT * FROM User WHERE User.id = ?", user_id)
        if sought_user.empty?
            next
        end

        followings = db.execute("SELECT User.id FROM User INNER JOIN User_follow_relation ON User.id = User_follow_relation.user_follows_this_id WHERE User_follow_relation.user_id = ?;", user_id) 
        followers = db.execute("SELECT User.id FROM User INNER JOIN User_follow_relation ON User.id = User_follow_relation.user_id WHERE User_follow_relation.user_follows_this_id = ?;", user_id)

        sought_user_complete = sought_user[0]
        # .map is syntactic sugar for extracting each id property out of the array of following/follower hashes
        sought_user_complete[:following_ids] = followings.map { |following| following["id"] }
        sought_user_complete[:follower_ids] = followers.map { |follower| follower["id"] }
        users.push(sought_user_complete)  
    end
    
    return users
end

def media(db, media_id)
    sought_media = db.execute("SELECT * FROM Media WHERE Media.id = ?", media_id)
    if sought_media.empty?
        return []
    end

    genres = db.execute("SELECT Genre.id FROM Genre INNER JOIN Media_genre_relation ON Genre.id = Media_genre_relation.genre_id WHERE Media_genre_relation.media_id = ?;", media_id)
    authors = db.execute("SELECT Author.id FROM Author INNER JOIN Media_author_relation ON Author.id = Media_author_relation.author_id WHERE Media_author_relation.media_id = ?;", media_id)

    sought_media_return = sought_media[0]
    # .map is syntactic sugar for extracting each id property out of the array of genre/author hashes
    sought_media_return[:genre_ids] = genres.map { |genre| genre["id"] } 
    sought_media_return[:author_ids] = authors.map { |author| author["id"]}
    return sought_media_return
end

def review(db, review_id)
    sought_review = db.execute("SELECT * FROM Review WHERE Review.id = ?", review_id)
    if sought_review.empty?
        return []
    end
    return sought_review
end

def user_reviews(db, user_id)
    reviews = db.execute("SELECT * FROM Review WHERE Review.user_id = ?;", user_id)
    return reviews
end

def followings_reviews(db, user_id) 
    followings = user(db, user_id)

    print(followings)

    followings_reviews = []
    followings.each do |following|
        followings_reviews = followings_reviews + user_reviews(db, following)
    end
    return followings_reviews
end

def user_ids_to_names(db, user_ids) 
   return users(db, user_ids).map {|user| user["name"]}
end