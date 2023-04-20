# TODO
# Lägg mer av logiken i model.rb. Kolla t.ex inte ifall en recension existerar i app.rb
# Använd resuce för att hantera errors
# Använd send_error() från model.rb
# Vissa dokumeterade parametrar i yardoc har felaktig datatyp. T.ex media_id som inte är en int utan en string (den görs om till en int efteråt)

require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"
require "date"
require "sinatra/reloader"
require_relative "./model.rb"

enable :sessions

include Model

db = database("./db/main.db")
# May be required for foreign keys to work
db.execute("PRAGMA foreign_keys = ON")

# YARDOC ROUTE TEMPLATE
# Deletes an existing article and redirects to '/articles'
#
# @param [Integer] :id, The ID of the article
# @param [String] :title, The new title of the article
# @param [String] :content, The new content of the article
#
# @see Model#delete_article

get("/") do
    # Replace 1 with user_id
    followings_reviews = followings_reviews(db, 1)
    slim(:"index", locals: { document_title: "Hem", followings_reviews: followings_reviews, db: db })
end

# Displays the meny for creating media
get("/users/new") do
    ## ADD IF LOGGED IN REDIRECT TO INDEX
    slim(:"users/new", locals: { document_title: "Skapa ett konto" })
end

# Creates a new user in the database
#
# @param [String] :username, the username for the new user
# @param [String] :password, the password for the new user
# @param [String] :password_confirmation, the password confirmation for the new user. Is going to be compared to :password
#
# @see Model#create_user
post("/users") do
    username = params[:username]
    password = params[:password]
    password_confirmation = params[:password_confirmation]
    begin
        create_user(db, username, password, password_confirmation)
    rescue Exception => e
        display_error(422, e)
    end
end

get("/search") {}

get("/media") do
    print(get_all_media(db))
    return(slim(:"media/index", locals: { db: db, media: get_all_media(db), document_title: "Alla medier" }))
end

# Displays the meny for creating media
get("/media/new") { slim(:"media/new", locals: { document_title: "Lägg till ett nytt medium" }) }

# Creates a new medium in the database
#
# @param [String] :medium_name, the name of the to-be created medium
# @param [String] :medium_type, the type of the to-be created medium (song, book, etc.)
# @param [String] :medium_creation_date, the creation date of the to-be created medium using an acceptable format that can be passed into the Date.parse function.
# @param [String] :medium_authors, the authors of the to-be created medium. NOTE, the authors are the ones who created the original medium refered to in the website, not the people who posted it to the webiste.
# @param [String] :medium_genres, the genres of this medium
# @param [String] :img_file, the uploaded image file through a HTML form
#
# @see Model#create_medium
post("/media") do
    unix_date = Date.parse(params[:medium_creation_date]).to_time.to_i
    medium = {
        name: params[:medium_name],
        type: params[:medium_type],
        creation_date: unix_date,
        authors: params[:medium_authors].split(","),
        genres: params[:medium_genres].split(","),
        img_file: params[:medium_pic]
    }

    print("Parsed medium #{medium}")

    #File.join("./public/img/media", params[:media_pic][:filename])
    #File.write(path, File.read(params[:media_pic][:tempfile]))

    medium_id = create_medium(db, medium)

    redirect("media/#{medium_id}")
end

get("/media/:media_id") do
    sought_id = params[:media_id].to_i
    sought_media = media(db, sought_id)

    if sought_media.empty?
        return(
            slim(:"error", locals: { document_title: "404", error_message: "The media specified is not found." })
        )
    end

    puts("Media: #{sought_media}")

    slim(:"media/show", locals: { db: db, document_title: sought_media["name"], medium: sought_media })
end

# Display the edit page for the specifed medium
#
# @param [String] :medium_name, the name of the to-be created medium
# @param [String] :medium_type, the type of the to-be created medium (song, book, etc.)
# @param [String] :medium_creation_date, the creation date of the to-be created medium using an acceptable format that can be passed into the Date.parse function.
# @param [String] :medium_authors, the authors of the to-be created medium. NOTE, the authors are the ones who created the original medium refered to in the website, not the people who posted it to the webiste.
# @param [String] :medium_genres, the genres of this medium
# @param [String] :img_file, the uploaded image file through a HTML form
#
# @param [String] :medium_id, The ID of the medium to be edited
#
# @see Model#media
get("/media/:medium_id/edit") do
    medium_id = params[:medium_id]

    medium = media(db, medium_id)

    display_error(404, "The medium ID specified does not exist.") if medium.empty?
    slim(:"media/edit", locals: { db: db, document_title: "Uppdatera mediumet", medium: medium })
end

# Updates a medium in the database
#
# @param [String] :medium_name, the new name of the medium
# @param [String] :medium_type, the new type of the medium (song, book, etc.)
# @param [String] :medium_creation_date, the new creation date of the medium using an acceptable format that can be passed into the Date.parse function.
# @param [String] :medium_authors, the new authors of the medium. NOTE, the authors are the ones who created the original medium refered to in the website, not the people who posted it to the webiste.
# @param [String] :medium_genres, the new genres of this medium
# @param [String] :img_file, the new uploaded image file for this medium through a HTML form
# @param [String] :medium_id, The ID of the medium to be edited
#
# @see Model#update_media
post("/media/:medium_id/update") do
    medium_id = params[:medium_id]

    puts("HEJ")

    updated_medium = {
        name: params[:medium_name],
        type: params[:medium_type],
        creation_date: params[:medium_creation_date],
        authors: params[:medium_authors].split(","),
        genres: params[:medium_genres].split(","),
        img_file: params[:medium_pic]
    }

    update_medium(db, medium_id, updated_medium)

    redirect("/media/#{medium_id}")
end

# Finds all reviews beloumging to a media
#
# @param [Integer] :media_id, The ID of the media
#
# @see Model#get_all_reviews
get("/media/:media_id/reviews") do
    media_id = params[:media_id].to_i
    reviews = get_all_reviews(db, media_id)
    slim(:"review/index", locals: { document_title: "Reviews", reviews: reviews, db: db })
end

# Displays the menu for creating reviews
#
# @param [Integer] :media_id, The ID of the media
get("/media/:media_id/reviews/new") do
    media_id = params[:media_id].to_i

    user_id = 1
    if does_user_have_review(db, user_id, media_id)
        return display_error(400, "User does already have a review for this medium.")
    end

    slim(:"review/new", locals: { document_title: "Ny recension", media_id: media_id, db: db })
end

# Creates a review-row in the database and redirects user if successful
#
# @param [Integer] :media_id, The ID of the media
# @param [Integer] :review_rating, the review rating specified by the user
# @param [Integer] :review_desc, the review description specified by the user
#
# @see Model#review
post("/media/:media_id/reviews") do
    media_id = params[:media_id].to_i
    review_rating = params[:review_rating].to_i
    review_desc = params[:review_desc]

    # Temporärt är den 1
    user_id = 1
    begin
        new_review_id = create_review(db, media_id, user_id, review_rating, review_desc)
        redirect("/media/#{media_id}/reviews/#{new_review_id}")
    rescue Exception => e
        display_error(400, e)
    end

    #slim(:"review/new", locals: { document_title: "Ny recension", media_id: media_id, db: db })
end

# Finds a specific review to a certain media
#
# @param [Integer] :media_id, The ID of the media
# @param [Integer] :review_id, The ID of the review
#
# @see Model#review
get("/media/:media_id/reviews/:review_id") do
    media_id = params[:media_id].to_i
    review_id = params[:review_id].to_i

    sought_review = review(db, review_id)

    if sought_review.empty? || sought_review["media_id"] != media_id
        return(
            slim(:"error", locals: { document_title: "404", error_message: "The review specified is not found." })
        )
    end

    media_name = media_id_to_name(db, sought_review["media_id"])

    slim(
        :"review/show",
        locals: {
            document_title: "Review: #{media_name}",
            review: sought_review,
            media_name: media_name,
            user_author_name: user_ids_to_names(db, [sought_review["user_id"]]),
            date: Time.at(sought_review["creation_date"]).to_date
        }
    )
end

# Displays the edit menu for a certain review
#
# @param [Integer] :media_id, The ID of the media
# @param [Integer] :review_id, The ID of the review
#
# @see Model#review
get("/media/:media_id/reviews/:review_id/edit") do
    media_id = params[:media_id].to_i
    review_id = params[:review_id].to_i

    sought_review = review(db, review_id)

    if sought_review.empty? || sought_review["media_id"] != media_id
        return(
            slim(:"error", locals: { document_title: "404", error_message: "The review specified is not found." })
        )
    end

    return(
        slim(
            :"review/edit",
            locals: {
                document_title: "Redigera en recension",
                review: sought_review,
                media_id: media_id
            }
        )
    )
end

# Updates a certain review in the specified database
# @param [SQLite3::Database] db, The database where the review and the media is stored
# @param [Integer] :media_id, The ID of the media
# @param [Integer] :review_id, The ID of the review
#
# @see Model#update_review
post("/media/:media_id/reviews/:review_id/edit") do
    media_id = params[:media_id].to_i
    review_id = params[:review_id].to_i

    if !update_review(
              db,
              media_id,
              review_id,
              { edited_review_desc: params[:review_desc], edited_review_rating: params[:review_rating] }
          )
        return(
            slim(:"error", locals: { document_title: "404", error_message: "The review specified is not found." })
        )
    end

    redirect("/media/#{media_id}/reviews/#{review_id}")
end

# Deletes an review and redirects to /review
#
# @param [Integer] :media_id, The ID of the media
# @param [Integer] :review_id, The ID of the to be deleted review
#
# @see Model#delete_review
post("/media/:media_id/reviews/:review_id/delete") do
    media_id = params[:media_id].to_i
    review_id = params[:review_id].to_i

    if !delete_review(db, media_id, review_id)
        return(
            slim(:"error", locals: { document_title: "404", error_message: "The review specified is not found." })
        )
    end

    redirect("/media/#{media_id}/reviews")
end

get("/users/:user_id") do
    sought_id = params[:user_id].to_i
    sought_user = users(db, [sought_id])[0]

    if sought_user.empty?
        return(
            slim(:"error", locals: { document_title: "404", error_message: "The the user specified is not found." })
        )
    end

    slim(
        :"user",
        locals: {
            document_title: sought_user["name"],
            user: sought_user,
            following_names: user_ids_to_names(db, sought_user[:following_ids]),
            follower_names: user_ids_to_names(db, sought_user[:follower_ids]),
            date: Time.at(sought_user["creation_date"]).to_date
        }
    )
end
