# TODO
# Lägg mer av logiken i model.rb. Kolla t.ex inte ifall en recension existerar i app.rb
# Använd resuce för att hantera errors
# Använd send_error() från model.rb

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
# YARDOC ROUTE TEMPLATE
# Deletes an existing article and redirects to '/articles'
#
# @param [Integer] :id, The ID of the article
# @param [String] title, The new title of the article
# @param [String] content, The new content of the article
#
# @see Model#delete_article

get("/") do
    # Replace 1 with user_id
    followings_reviews = followings_reviews(db, 1)
    slim(:"index", locals: { document_title: "Hem", followings_reviews: followings_reviews, db: db })
end

get("/signup") {}

get("/search") {}

# Putting this before /review/:review_id so it matches this first, otherwise it will think that new is an id
get("/media/new") { return(slim(:"review/new", locals: { document_title: "Publisera en recension" })) }

get("/media/:media_id") do
    sought_id = params[:media_id].to_i
    sought_media = media(db, sought_id)

    if sought_media.empty?
        return(
            slim(:"error", locals: { document_title: "404", error_message: "The media specified is not found." })
        )
    end

    slim(
        :"media",
        locals: {
            document_title: sought_media["name"],
            media: sought_media,
            author_names: author_ids_to_names(db, sought_media[:author_ids]),
            genre_names: genre_ids_to_names(db, sought_media[:genre_ids]),
            date: Time.at(sought_media["creation_date"]).to_date
        }
    )
end

# Finds all reviews belonging to a media
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

    slim(:"review/new", locals: { document_title: "Ny recension", media_id: media_id, db: db })
end

post("/media/:media_id/reviews") do
    media_id = params[:media_id].to_i
    review_rating = params[:review_rating].to_i
    review_desc = params[:review_desc]

    # Temporärt är den 1
    user_id = 1
    begin
        print(create_review(db, media_id, user_id, review_rating, review_desc))
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
get("/media/:media_id/review/:review_id/delete") do
    media_id = params[:media_id].to_i
    review_id = params[:review_id].to_i

    if !delete_review(db, media_id, review_id)
        return(
            slim(:"error", locals: { document_title: "404", error_message: "The review specified is not found." })
        )
    end

    redirect("/review")
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
