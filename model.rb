# TODO
# Använd "helpers" mer
# Använd raise för att kasta errors

# YARDOC DOCUMENTATION TEMPLATE FOR FUNCTIONS
# Attempts to insert a new row in the articles table
#
# @param [Hash] params form data
# @option params [String] title The title of the article
# @option params [String] content The content of the article
#
# @return [Hash]
#   * :error [Boolean] whether an error occured
#   * :message [String] the error message
helpers do
    def user_ids_to_names(db, user_ids)
        return users(db, user_ids).map { |user| user["name"] }
    end

    def media_id_to_name(db, media_id)
        return db.execute("SELECT Media.name FROM Media WHERE Media.id = ?;", media_id)[0]["name"]
    end

    def format_unix_timestamp(timestamp)
        return Time.at(timestamp).to_date
    end

    def author_ids_to_names(db, author_ids)
        author_names = []
        print(author_ids)
        author_ids.each do |author_id|
            author_names.push(
                db.execute("SELECT Author.name FROM Author WHERE Author.id = ?;", author_id)[0]["name"]
            )
        end
        return author_names
    end

    def genre_ids_to_names(db, genre_ids)
        genre_names = []
        genre_ids.each do |genre_id|
            genre_names.push(db.execute("SELECT Genre.name FROM Genre WHERE Genre.id = ?;", genre_id)[0]["name"])
        end
        return genre_names
    end
end

module Model
    def database(path)
        db = SQLite3::Database.new("db/main.db")
        db.results_as_hash = true
        return db
    end

    # Checks if review ID exist and belongs belongs to a certain media in the database
    #
    # @param [SQLite3::Database] database where review is stored
    # @param [Number] the media's id in the database
    # @param [Number] the review's id in the database
    #
    # @return [Boolean] if it exist
    def does_review_exist(db, media_id, review_id)
        review = review(db, review_id)
        if review(db, review_id).empty? || media_id = !review["media_id"]
            return false
        else
            return true
        end
    end

    # Checks if user has already published a review for a specific media
    #
    # @param [SQLite3::Database] database where review is stored
    # @param [Number] the media's id in the database
    # @param [Number] the ID belongning to the user that is being checked
    #
    # @return [Boolean] if it exist
    def does_user_have_review(db, user_id, media_id)
        puts("Does user already have review?")
        user_reviews = db.execute("SELECT * FROM Review WHERE user_id = ? AND media_id = ?", user_id, media_id)
        if user_reviews.empty?
            puts("USER #{user_id} DOES NOT HAVE REVIEWS")
            return false
        end
        return true
    end

    # Checks if a user with the specified username exist in the database
    #
    # @param [SQLite3::Database] database where review is stored
    # @param [String] the username that is going to be checked
    #
    # @return [Boolean] if it exist

    def does_user_exist(db, username)
        return false if db.execute("SELECT id FROM User WHERE name = ?", username).empty?

        return true
    end

    # Displays an error site customized with the error provided
    #
    # @param [Number] the HTTP response status code the error is going to have
    # @param [Number] the error message that will be displayed
    #
    # @return [Nil]
    def display_error(status, msg)
        slim(:"error", locals: { document_title: status.to_s, error_message: msg })
    end

    def users(db, user_ids)
        users = []
        user_ids.each do |user_id|
            sought_user = db.execute("SELECT * FROM User WHERE User.id = ?", user_id)
            next if sought_user.empty?

            followings =
                db.execute(
                    "SELECT User.id FROM User INNER JOIN User_follow_relation ON User.id = User_follow_relation.user_follows_this_id WHERE User_follow_relation.user_id = ?;",
                    user_id
                )
            followers =
                db.execute(
                    "SELECT User.id FROM User INNER JOIN User_follow_relation ON User.id = User_follow_relation.user_id WHERE User_follow_relation.user_follows_this_id = ?;",
                    user_id
                )

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
        return [] if sought_media.empty?
        genres =
            db.execute(
                "SELECT Genre.id FROM Genre INNER JOIN Media_genre_relation ON Genre.id = Media_genre_relation.genre_id WHERE Media_genre_relation.media_id = ?;",
                media_id
            )
        authors =
            db.execute(
                "SELECT Author.id FROM Author INNER JOIN Media_author_relation ON Author.id = Media_author_relation.author_id WHERE Media_author_relation.media_id = ?;",
                media_id
            )

        sought_media_return = sought_media[0]
        # .map is syntactic sugar for extracting each id property out of the array of genre/author hashes
        sought_media_return[:genre_ids] = genres.map { |genre| genre["id"] }
        sought_media_return[:author_ids] = authors.map { |author| author["id"] }
        return sought_media_return
    end

    def get_all_media(db)
        media = db.execute("SELECT * FROM Media")
        return [] if media.empty?
        media_return = []
        media.each do |medium|
            media_return.push(medium)
            genres =
                db.execute(
                    "SELECT Genre.id FROM Genre INNER JOIN Media_genre_relation ON Genre.id = Media_genre_relation.genre_id WHERE Media_genre_relation.media_id = ?;",
                    medium["id"]
                )
            authors =
                db.execute(
                    "SELECT Author.id FROM Author INNER JOIN Media_author_relation ON Author.id = Media_author_relation.author_id WHERE Media_author_relation.media_id = ?;",
                    medium["id"]
                )
            media_return[-1][:genre_ids] = genres.map { |genre| genre["id"] }
            media_return[-1][:author_ids] = authors.map { |author| author["id"] }
        end

        return media_return
    end

    def review(db, review_id)
        sought_review = db.execute("SELECT * FROM Review WHERE Review.id = ?", review_id)
        return [] if sought_review.empty?
        return sought_review[0]
    end

    def get_all_reviews(db, media_id)
        reviews = db.execute("SELECT * FROM Review WHERE Review.media_id = ?", media_id)
        return [] if reviews.empty?

        reviews = reviews.sort_by { |review| review["creation_date"] * -1 }

        return reviews
    end

    def user_reviews(db, user_id)
        print(user_id)
        reviews = db.execute("SELECT * FROM Review WHERE Review.user_id = ?;", user_id)
        return reviews
    end

    def followings_reviews(db, user_id)
        followings = users(db, [user_id])[0][:following_ids]

        #print("Followings: ")
        #print(followings)

        followings_reviews = []
        followings.each { |following| followings_reviews = followings_reviews + user_reviews(db, following) }

        followings_reviews = followings_reviews.sort_by { |review| review["creation_date"] * -1 }

        return followings_reviews
    end

    # Updates the specified review in the database provided with provided information
    #
    # @param [SQLite3::Database] database where review is stored
    # @param [Number] the the media id belonging to the review in the database
    # @param [Number] the review's id in the database
    # @param [Hash] the update review
    #   * :edited_review_rating [Number] the new review rating
    #   * :edited_review_desc [String] the new review description
    #
    # @return [Boolean] was it updated?
    def update_review(db, media_id, review_id, updated_review)
        if does_review_exist(db, media_id, review_id)
            db.execute(
                "UPDATE Review
                SET content = ?, rating = ?, creation_date = ? 
                WHERE id = ?; ",
                updated_review[:edited_review_desc],
                updated_review[:edited_review_rating],
                Time.now.to_i,
                review_id
            )
            return true
        else
            return false
        end
    end

    # Deletes specifed review in the database provided
    #
    # @param [SQLite3::Database] database where review is stored
    # @param [Number] the the media id belonging to the review in the database
    # @param [Number] the review's id in the database
    #
    # @return [Boolean] was it deleted?
    def delete_review(db, media_id, review_id)
        if does_review_exist(db, media_id, review_id)
            db.execute("DELETE FROM Review WHERE id = ?", review_id)
            return true
        else
            return false
        end
    end

    # Inserts a newly created review into the database
    #
    # @param [SQLite3::Database] database where review is stored
    # @param [Number] the the media id belonging to the review in the database
    # @param [Number] the review's id in the dat
    #
    # @return [Number] the id of the newly created revi ew
    def create_review(db, media_id, user_id, rating, desc)
        print("USER IS SITLL #{user_id}")
        raise "User review already exist for this media." if (does_user_have_review(db, user_id, media_id))
        db.execute(
            "INSERT INTO Review (media_id, user_id, rating, content, creation_date) VALUES (?, ?, ?, ?, ?)",
            media_id,
            user_id,
            rating,
            desc,
            Time.now.to_i
        )
        return db.last_insert_row_id()
    end

    # Calculates a total rating for a medium based on user reviews and updates the database
    #
    # @param [SQLite3::Database] database where review is stored
    # @param [Number] the id of the media that is updated
    #
    # @return [Nil]
    def update_rating(db, media_id)
        ratings = db.execute("SELECT rating FROM Review WHERE media_id = ?", media_id)
        ratings_sum = 0
        ratings.each { |rating| ratings_sum += rating["rating"] }
        average = (ratings_sum / ratings.length.to_f).round(1)
        db.execute("UPDATE Media SET total_rating = ? WHERE id = ?", average, media_id)
    end

    # Creates a medium in the database and saves the image
    #
    # @param [SQLite3::Database] database where review is s
    # @param [Hash] the medium to be created
    #   * :name [String] the medium name
    #   * :type [String] the medium type (book, song, etc.)
    #   * :creation_date [Number] the unix timestamp for the mediums creation date
    #   * :authors [Array<String>] the original authors of the medium
    #   * :genres [Array<String>] the genres belonging to the medium
    #   * :img_file [Hash] the hash of the img file. It has the structure of a uploaded file through a HTMl form.
    #
    # @return [Number] the id of the newly created medium

    def create_medium(db, medium)
        path = File.join("./public/img/uploaded_img/media", medium[:img_file][:filename])

        puts("The path to the uploaded file: #{path}")
        puts("The supposed tempfile: #{medium[:img_file][:tempfile]}")
        File.open(path, "wb") { |f| f.write(medium[:img_file][:tempfile].read) }

        db.execute(
            "INSERT INTO Media (name, total_rating, type, creation_date, picpath) VALUES (?, ?, ?, ?, ?)",
            medium[:name],
            nil,
            medium[:type],
            medium[:creation_date],
            medium[:img_file][:filename]
        )

        media_id = db.last_insert_row_id()

        medium[:authors].each do |author|
            author_id = db.execute("SELECT id FROM Author WHERE name = ? ", author)

            if author_id.empty?
                db.execute("INSERT INTO Author (name) VALUES (?)", author)
                author_id = ["id" => db.last_insert_row_id()]
            end

            puts("AUTHOR ID: #{author_id}")

            db.execute(
                "INSERT INTO Media_author_relation (author_id, media_id) VALUES (?, ?)",
                author_id[0]["id"],
                media_id
            )
        end

        medium[:genres].each do |genre|
            genre_id = db.execute("SELECT * FROM Genre WHERE name = ? ", genre)
            if genre_id.empty?
                db.execute("INSERT INTO Genre (name) VALUES (?)", genre)
                genre_id = ["id" => db.last_insert_row_id()]
            end

            db.execute(
                "INSERT INTO Media_genre_relation (genre_id, media_id) VALUES (?, ?)",
                genre_id[0]["id"],
                media_id
            )
        end

        return media_id
    end

    def create_user(db, username, password, password_confirmation)
        raise "A user with the provided username does already exist." if does_user_exist(db, username)

        raise "Passwords does not match." if password != password_confirmation

         
    end
end
