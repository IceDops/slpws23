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

    # Converts a date string from an HTML form to an unix timestamp
    #
    # @param [String] the date string from an HTML form
    #
    # @return [Number] The unix timestamp
    def date_string_to_unix(string)
        return Date.parse(string).to_time.to_i
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
    def does_username_exist(db, username)
        return false if db.execute("SELECT id FROM User WHERE name = ?", username).empty?
        return true
    end

    # Checks if a user with the specified ID exist in the database
    #
    # @param [SQLite3::Database] database where review is stored
    # @param [Number] the user ID that is going to be checked
    #
    # @return [Boolean] if it exist
    def does_user_id_exist(db, user_id)
        return false if db.execute("SELECT * FROM User WHERE id = ?", user_id).empty?
        return true
    end

    def does_medium_exist(db, medium_id)
        return false if db.execute("SELECT * FROM Media WHERE id = ?", medium_id).empty?
        return true
    end

    # Displays an error site customized with the error provided
    #
    # @param [Number] the HTTP response status code the error is going to have
    # @param [Number] the error message that will be displayed
    #
    # @return [Nil]
    def display_error(msg)
        slim(:"error", locals: { document_title: "Error", error_message: msg })
    end

    def users(db, user_ids = nil)
        users = []
        user_ids = db.execute("SELECT id FROM User").map { |id_obj| id_obj["id"] } if user_ids == nil
        user_ids.each do |user_id|
            print("USER ID: #{user_id}")
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
        print(users)
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
        puts("USER ID: #{user_id}")
        followings = users(db, [user_id])[0][:following_ids]

        #print("Followings: ")
        #print(followings)

        followings_reviews = []
        followings.each { |following| followings_reviews = followings_reviews + user_reviews(db, following) }

        followings_reviews = followings_reviews.sort_by { |review| review["creation_date"] * -1 }

        return followings_reviews
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
            update_rating(db, media_id)
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
            update_rating(db, media_id)
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
        update_rating(db, media_id)
        return db.last_insert_row_id()
    end

    def insert_media_author_relation(db, author_id, medium_id)
        print("TRYING TO INSERT NEW RELATION, AUTHOR ID: #{author_id}, MEDIUM ID: #{medium_id}")
        media_author_relation =
            db.execute(
                "SELECT * FROM Media_author_relation WHERE author_id = ? AND media_id = ? ",
                author_id,
                medium_id
            )
        if media_author_relation.empty?
            db.execute(
                "INSERT INTO Media_author_relation (author_id, media_id) VALUES (?, ?)",
                author_id,
                medium_id
            )
        end
    end

    def insert_media_genre_relation(db, genre_id, medium_id)
        media_genre_relation =
            db.execute(
                "SELECT * FROM Media_genre_relation WHERE genre_id = ? AND media_id = ? ",
                genre_id,
                medium_id
            )
        if media_genre_relation.empty?
            db.execute("INSERT INTO Media_genre_relation (genre_id, media_id) VALUES (?, ?)", genre_id, medium_id)
        end
    end

    # Writes a img file uploaded thorugh an HTML form to a folder on the server
    #
    # @param [String] the filename of the image file
    # @param [String] the name of the folder in the "uploaded_img" directory where the image should be written to
    # @param [Hash] the image content uploaded through an HTML form
    def write_image(filename, folder, content)
        path = File.join("./public/img/uploaded_img/#{folder}", filename)
        File.open(path, "wb") { |f| f.write(content.read) }
    end

    # Creates a medium in the database and saves the image
    #
    # @param [SQLite3::Database] database where review is
    # @param [Hash] the medium to be created
    #   * :name [String] the medium name
    #   * :type [String] the medium type (book, song, etc.)
    #   * :creation_date [Number] the unix timestamp for the mediums creation date
    #   * :authors [Array<String>] the original authors of the medium
    #   * :genres [Array<String>] the genres belonging to the medium
    #   * :img_file [Hash, Nil] the hash of the img file. It has the structure of a uploaded file through a HTMl form.
    #
    # @return [Number] the id of the newly created medium
    def create_medium(db, medium)
        img_file = nil
        if medium[:img_file]
            img_file = medium[:img_file]
            write_image(medium[:img_file][:filename], media, medium[:img_file][:tempfile])
        end

        db.execute(
            "INSERT INTO Media (name, total_rating, type, creation_date, picpath) VALUES (?, ?, ?, ?, ?)",
            medium[:name],
            nil,
            medium[:type],
            medium[:creation_date],
            medium[:img_file]
        )

        media_id = db.last_insert_row_id()

        medium[:authors].each do |author|
            author_id = db.execute("SELECT id FROM Author WHERE name = ? ", author)

            if author_id.empty?
                db.execute("INSERT INTO Author (name) VALUES (?)", author)
                author_id = ["id" => db.last_insert_row_id()]
            end
            insert_media_author_relation(db, author_id[0]["id"], media_id)
        end

        print("LOOKING FOR GENRES IN #{medium}")
        medium[:genres].each do |genre|
            print("INSERTING genre: #{genre}")
            genre_id = db.execute("SELECT * FROM Genre WHERE name = ? ", genre)
            if genre_id.empty?
                db.execute("INSERT INTO Genre (name) VALUES (?)", genre)
                genre_id = ["id" => db.last_insert_row_id()]
            end
            insert_media_genre_relation(db, genre_id[0]["id"], media_id)
        end

        return media_id
    end
    #
    # @param [SQLite3::Database] database where authors and relations between the authors and the media are stored.
    # @param [Array<Number>] the IDs of authors that belongs to the specified medium
    # @param [Number] the id of the medium which the specified authors has relations to
    #
    # @return [Nil]
    def clean_authors(db, author_ids, medium_id)
        puts("CLEANING FOR AUTHOR_IDS: #{author_ids}")
        medium_relations = db.execute("SELECT * FROM Media_author_relation WHERE media_id = ?", medium_id)
        medium_relations.each do |medium_relation|
            if not author_ids.include? medium_relation["author_id"]
                puts("DELETING RELATION: #{medium_relation}")
                db.execute(
                    "DELETE FROM Media_author_relation WHERE media_id = ? AND author_id = ?",
                    medium_id,
                    medium_relation["author_id"]
                )
                # Delete the whole author if the author does not belong to any medium
                author_relations =
                    db.execute("SELECT * FROM Media_author_relation WHERE author_id = ?", medium_relation["author_id"])
                db.execute("DELETE FROM Author WHERE id = ?", medium_relation["author_id"]) if author_relations.empty?
            end
        end
    end

    # Same as above. May be a bit repetetive but there will be too much parameters otherwise

    # Remove old relations between genres and medium. Can also remove genre if does not have any relations left to media.
    #
    # @param [SQLite3::Database] database where genres and relations between the genres and the media are stored.
    # @param [Array<Number>] the IDs of genres belongs to the specified medium
    # @param [Number] the id of the medium which the specified genres has relations to
    #
    # @return [Nil]
    def clean_genres(db, genre_ids, medium_id)
        genre_relations = db.execute("SELECT * FROM Media_genre_relation WHERE media_id = ?", medium_id)
        genre_relations.each do |genre_relation|
            if not genre_ids.include? genre_relation["genre_id"]
                db.execute(
                    "DELETE FROM Media_genre_relation WHERE media_id = ? AND genre_id = ?",
                    medium_id,
                    genre_relation["genre_id"]
                )
                # Delete the whole genre if the author does not belong to any medium
                genre_relations =
                    db.execute("SELECT * FROM Media_genre_relation WHERE genre_id = ?", genre_relation["genre_id"])
                db.execute("DELETE FROM Genre WHERE id = ?", genre_relation["genre_id"]) if genre_relations.empty?
            end
        end
    end

    # Deletes a medium cover picture stored in the project folder if it's not being used by any medium
    #
    #
    # @param [SQLite3::Database] database where media pictures are stored
    # @param [String] the medium cover picture's filename that is going to be deleted
    #
    # @return [Nil]
    def clean_medium_pic(db, filename)
        if db.execute("SELECT * FROM Media WHERE picpath = ?", filename).empty?
            path = File.join("./public/img/uploaded_img/media", filename)
            File.delete(path)
        end
    end

    # Deletes a pfp stored in the project folder if it's not being used by any user
    #
    # @param [SQLite3::Database] database where media pictures are stored
    # @param [String] the medium cover picture's filename that is going to be deleted
    #
    # @return [Nil]
    def clean_user_pic(db, filename)
        if db.execute("SELECT * FROM User WHERE picpath = ?", filename).empty?
            path = File.join("./public/img/uploaded_img/profile", filename)
            File.delete(path)
        end
    end

    # Updates the specified medium in the database
    #
    # @param [SQLite3::Database] database where genres and relations between the genres and the media are stored.
    # @param [Number] the ID of the medium in the database to be updated
    # @param [Hash] the properites of the edited medium
    #   * :name [String] the new medium name
    #   * :type [String] the new medium type (book, song, etc.)
    #   * :creation_date [Number] the new unix timestamp for the mediums creation date
    #   * :authors [Array<String>] the new original authors of the medium
    #   * :genres [Array<String>] the new genres belonging to the medium
    #   * :img_file [Hash, Nil] the hash of the new img file. It has the structure of a uploaded file through a HTMl form. Can be nil picture should not be changed.
    #
    # @return [Nil]
    def update_medium(db, medium_id, updated_medium)
        if updated_medium[:img_file] != nil
            old_relative_path = db.execute("SELECT picpath FROM Media WHERE id = ?", medium_id)[0]["picpath"]

            puts("OLD RELATIVE PATH: #{old_relative_path}")

            path = File.join("./public/img/uploaded_img/media", updated_medium[:img_file][:filename])
            File.open(path, "wb") { |f| f.write(updated_medium[:img_file][:tempfile].read) }
            db.execute(
                "UPDATE Media
                SET picpath = ? 
                WHERE id = ?; ",
                updated_medium[:img_file][:filename],
                medium_id
            )

            clean_medium_pic(db, old_relative_path) if not old_relative_path == nil
        end

        db.execute(
            "UPDATE Media
                SET name = ?, type = ?, creation_date = ? 
                WHERE id = ?; ",
            updated_medium[:name],
            updated_medium[:type],
            updated_medium[:creation_date],
            medium_id
        )

        author_ids = []

        puts("AUTHORS: #{updated_medium[:authors]}")

        updated_medium[:authors].each do |author|
            author_id = db.execute("SELECT id FROM Author WHERE name = ? ", author)
            next if author_ids.include? author_id[0]
            if author_id.empty?
                puts("#{author} FINNS INTE!!!")
                puts("INSERTING #{author}")
                db.execute("INSERT INTO Author (name) VALUES (?)", author)
                author_id = ["id" => db.last_insert_row_id()]
                #puts("AUTHOR ID: #{author_id}")
            end
            author_ids.push(author_id[0]["id"])
            insert_media_author_relation(db, author_id[0]["id"], medium_id)
        end

        clean_authors(db, author_ids, medium_id)

        # HANDLE GENRES
        genre_ids = []
        updated_medium[:genres].each do |genre|
            genre_id = db.execute("SELECT id FROM Genre WHERE name = ? ", genre)
            next if genre_ids.include? genre_id[0]
            if genre_id.empty?
                db.execute("INSERT INTO Genre (name) VALUES (?)", genre)
                genre_id = ["id" => db.last_insert_row_id()]
            end

            genre_ids.push(genre_id[0]["id"])
            insert_media_genre_relation(db, genre_id[0]["id"], medium_id)
        end
        clean_genres(db, genre_ids, medium_id)
    end

    def delete_medium(db, medium_id)
        if does_medium_exist(db, medium_id)
            db.execute("DELETE FROM Media WHERE id = ?", medium_id)
            clean_genres(db, [], medium_id)
            clean_authors(db, [], medium_id)
        else
            raise "Medium is not found."
        end
    end

    def validate_username(db, username)
        raise "En användare med det användarnamnet existerar redan." if does_username_exist(db, username)
        # VALIDATING
        if username.match(/[^a-zA-Z\d]/)
            raise "Användarnamnet innehåller förbjudna karraktärer. Endast a-z och siffror är tillåtna."
        end
        raise "Användarnamnet måste vara minst 2 karraktärer långt" if username.length < 2
        raise "Användarnamnet får max var 32 karraktärer långt" if username.length > 32
    end

    def validate_password(password, password_confirmation)
        raise "Lösenorden matchar inte." if password != password_confirmation
        raise "Lösenordet måste vara minst 6 karraktärer långt" if password.length < 6
        raise "Lösenordet får max var 32 karraktärer långt" if password.length > 32
        if password.match(/[^a-zA-Z\d@$#!?%^&*]/)
            raise "Lösenordet innehåller förbjudna karraktärer. Endast bokstäver, siffror och symbolerna @$#!?%^&* är tillåtna."
        end
    end

    # Creates a new user in the database
    #
    # @param [SQLite3::Database] database where users are stored
    # @param [String] the username of the to-be created user
    # @param [String] the password of the to-be created user
    # @param [String] the password confirmation of the to-be created user
    #
    # @return [Number] the id of the new user
    def create_user(db, username, password, password_confirmation)
        validate_username(db, username)
        validate_password(password, password_confirmation)
        password_digest = BCrypt::Password.create(password)
        db.execute(
            "INSERT INTO User (name, pwddigest, type, picpath, creation_date) VALUES (?, ?, ?, ?, ?)",
            username,
            password_digest,
            "user",
            nil,
            Time.now.to_i
        )
        return db.last_insert_row_id
    end

    def update_user(db, user_id, updated_user)
        if does_user_id_exist(db, user_id)
            db.execute("UPDATE User SET type = ? WHERE id = ?", updated_user[:type], user_id)

            username = updated_user[:username]
            if username && username.length > 0
                validate_username(db, updated_user[:username])
                db.execute("UPDATE User SET name = ? WHERE id = ?", username, user_id)
            end

            if updated_user[:user_pic] && updated_user[:user_pic] != ""
                write_image(updated_user[:user_pic][:filename], "profile", updated_user[:user_pic][:tempfile])
                old_user_pic = db.execute("SELECT picpath FROM User WHERE id = ?", user_id)[0]["picpath"]
                db.execute("UPDATE User SET picpath = ? WHERE id = ?", updated_user[:user_pic][:filename], user_id)
                clean_user_pic(db, old_user_pic)
            end

            password = updated_user[:password]
            password_confirmation = updated_user[:password_confirmation]
            if password && password != "" && password_confirmation
                validate_password(password, password_confirmation)
                password_digest = BCrypt::Password.create(password)
                db.execute("UPDATE User SET pwddigest = ? WHERE id = ?", password_digest, user_id)
            end
        else
            raise "User does not exist"
        end
    end

    # Deletes a user from the database
    #
    # @param [SQLite3::Database] database where users are stored
    # @param [Number] the user ID of the to-be deleted user
    #
    # @return [Nil]
    def delete_user(db, user_id)
        if does_user_id_exist(db, user_id)
            db.execute("DELETE FROM User WHERE id = ?", user_id)
        else
            raise "User does not exist"
        end
    end
end
