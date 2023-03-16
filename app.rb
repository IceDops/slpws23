require "sinatra"
require "slim"
require "sqlite3"
require "bcrypt"
require "date"
require "sinatra/reloader"
require_relative "./model.rb"

enable :sessions

db = database("./db/main.db")

get('/') do 
    # Replace 1 with user_id
    followings_reviews = followings_reviews(db, 1)
    slim(:"index", locals:{document_title: "Hem", followings_reviews: followings_reviews, db: db})
end

get("/signup") do

end

get("/search") do

end

get("/review") do
    reviews = get_all_reviews(db)
    slim(:"review/index", locals:{document_title: "Reviews", reviews: reviews, db: db})
end

# Putting this before /review/:review_id so it matches this first, otherwise it will think that new is an id 
get("/review/new") do
    return slim(:"review/new", locals:{document_title: "Publisera en recension"})
end

get("/review/:review_id/edit") do
    sought_id = params[:review_id].to_i
    review = review(db, sought_id)

    return slim(:"review/edit", locals:{document_title: "Redigera en recension", review: review})
end


get("/review/:review_id") do

    sought_id = params[:review_id].to_i
    sought_review = review(db, sought_id)


    if sought_review.empty?
       return slim(:"error", locals:{document_title: "404", error_message: "The review specified is not found."})
    end

    media_name = media_id_to_name(db, sought_review["media_id"])
    print(sought_review["user_id"])

    slim(:"review/show", locals:{document_title: "Review: #{media_name}", review: sought_review, 
        media_name: media_name, user_author_name: user_ids_to_names(db, [sought_review["user_id"]]), date: Time.at(sought_review["creation_date"]).to_date
    })
end

get("/user/:user_id") do
    sought_id = params[:user_id].to_i
    sought_user = users(db, [sought_id])[0]

    if sought_user.empty?
       return slim(:"error", locals:{document_title: "404", error_message: "The the user specified is not found."})
    end

    slim(:"user", locals: {document_title: sought_user["name"],
        user: sought_user, following_names: user_ids_to_names(db, sought_user[:following_ids]), 
        follower_names: user_ids_to_names(db, sought_user[:follower_ids]), date: Time.at(sought_user["creation_date"]).to_date
    }) 
end

get("/media/:media_id") do
    sought_id = params[:media_id].to_i
    sought_media = media(db, sought_id) 

    if sought_media.empty?
       return slim(:"error", locals:{document_title: "404", error_message: "The media specified is not found."})
    end
     
    slim(:"media", locals:{document_title: sought_media["name"], 
        media: sought_media, author_names: author_ids_to_names(db, sought_media[:author_ids]), 
        genre_names: genre_ids_to_names(db, sought_media[:genre_ids]), date: Time.at(sought_media["creation_date"]).to_date
    })
end