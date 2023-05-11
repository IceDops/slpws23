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

db = database()
# May be required for foreign keys to work
db.execute("PRAGMA foreign_keys = ON")

Cooldown = 3
Flush_time = 20
login_logs = []

# Checks if user that sent request has the right permissions, otherwise redirect it to root
#
# @param [SQLite3::Database] db the database where users are stored
# @param [Number] session_user_id the user id that is stored in the session
# @param [String] type the permission level for a specific route. "Mod" means only mods are allowed, "user" means mods and users that own the resource and "guest" means everyone that is logged in
# @param [Number] *param_user_id the user id that owns a specific resource. Is used for permission level "user".
#
# @return [Nil]
def authorize_request(db, session_user_id, type, *param_user_id)
    return redirect("/") if !session_user_id
    return if type == "guest"

    user_type = users(db, [session_user_id])[0]["type"]
    return if type == "user" && param_user_id[0] == session_user_id
    return if user_type == "mod"

    redirect("/")
end

# YARDOC ROUTE TEMPLATE
# Deletes an existing article and redirects to '/articles'
#
# @param [Integer] :id, The ID of the article
# @param [String] :title, The new title of the article
# @param [String] :content, The new content of the article
#
# @see Model#delete_article

#before do
#    mod_routes = [
#        { method: "GET", path: %r{^/media/new$} },
#        { method: "POST", path: %r{^/media$} },
#        { method: "GET", path: %r{^/media/\d*/edit$} },
#        { method: "POST", path: %r{^/media/\d*/update$} },
#        { method: "POST", path: %r{^/media/\d*/delete$} },
#    ]
#
#    user_routes = []
#    mod_routes.each { |mod_route| authorize_mod_request(db, request, mod_route, session[:user_id]) }
#end
#
#%w[/users/:user_id/edit /users/:user_id/update /users/:user_id/delete].each do |user_path|
#    before user_path do
#        user_id = params[:user_id]
#    end
#end

# Displays welcome site
get("/") { slim(:"index", locals: { document_title: "Hem", db: db }) }

# Display site for logging in
get("/login") { slim(:"login", locals: { document_title: "Alla användare", users: users(db), db: db }) }

# Logs in the user to the website
#
# @param [String] params[:username] the username of the user to be logged in to
# @param [String] params[:password] the password of the user to be logged in to
#
# @see Model#validate_login
post("/login") do
    username = params[:username]
    password = params[:password]

    cooldowned = false

    login_logs.each do |log|
        cooldowned = true if log[:username] == username && Time.now - log[:time] <= Cooldown
        # Flush cooldowns
        login_logs = [] if login_logs[0] && Time.now - login_logs[0][:time] >= Flush_time

        if cooldowned
            return(
                display_error(
                    db,
                    "Inloggning för detta konto har temporärt deaktiverats för att skydda mot brute force. Testa igen om ett litet tag."
                )
            )
        end
    end

    login_logs.push({ username: username, time: Time.now })

    begin
        user_id = validate_login(db, username, password)
    rescue Exception => e
        return display_error(db, e)
    end

    session[:user_id] = user_id if user_id
    redirect("/")
end

# Logs out the user
get("/logout") do
    session.destroy
    redirect("/")
end

# Displays all users registred in the database
#
# @see Model#users
get("/users") { slim(:"users/index", locals: { document_title: "Alla användare", users: users(db), db: db }) }

# Displays the meny for creating media
#
# @param [Number | Nil] session[:user_id] the id of a potential logged in user
get("/users/new") do
    redirect("/") if session[:user_id]
    slim(:"users/new", locals: { document_title: "Skapa ett konto", db: db })
end

# Displays information about a specified user from the database
#
# @param [String] params[:user_id] the id of the user that is being looked up
#
# @see Model#users
get("/users/:user_id") do
    user_id = params[:user_id].to_i
    user = users(db, [user_id])
    return display_error(db, "User not found.") if user.empty?

    slim(:"users/show", locals: { document_title: "Användare", user: user[0], db: db })
end

# Displays a menu for editing a specific user
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [String] params[:user_id] the id of the user that is edited
#
# @see Model#users
get("/users/:user_id/edit") do
    user_id = params[:user_id].to_i
    authorize_request(db, session[:user_id], "user", user_id)

    user = users(db, [user_id])
    return display_error(db, "User not found.") if user.empty?
    slim(:"users/edit", locals: { document_title: "Ändra användare", user: user[0], db: db })
end

# Updates a user's information in the database
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [String] params[:user_id] the id of the user that is being updated
# @param [String] params[:username] the new username of the user that is being updated
# @param [String] params[:password] the new password of the user that is being updated
# @param [String] params[:password_confirmation] password confirmation for the new password
# @param [String, Nil] params[:user_pic] the new pfp for the user that is being updated
#
# @see Model#update_user
post("/users/:user_id/update") do
    user_id = params[:user_id].to_i
    authorize_request(db, session[:user_id], "user", user_id)

    user = users(db, [session[:user_id]])

    if user[0]["type"] == "mod" && params[:type]
        type = "mod"
    else
        type = "user"
    end

    updated_user = {
        username: params[:username],
        password: params[:password],
        password_confirmation: params[:password_confirmation],
        type: type,
        user_pic: params[:user_pic]
    }
    begin
        update_user(db, user_id, updated_user)
    rescue Exception => e
        return display_error(db, e)
    end
    redirect("/users/#{user_id}")
end

# Deletes a specific user from the database
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [String] params[:user_id] the id of the user that is going to be deleted
#
# @see Model#delete_user
post("/users/:user_id/delete") do
    user_id = params[:user_id].to_i
    authorize_request(db, session[:user_id], "user", user_id)

    begin
        delete_user(db, user_id)
        redirect("/users")
    rescue Exception => e
        return display_error(db, e)
    end
end

# Creates a new user in the database
#
# @param [String] params[:username] the username for the new user
# @param [String] params[:password] the password for the new user
# @param [String] params[:password_confirmation] the password confirmation for the new user. Is going to be compared to :password
#
# @see Model#create_user
post("/users") do
    username = params[:username]
    password = params[:password]
    password_confirmation = params[:password_confirmation]

    begin
        user_id = create_user(db, username, password, password_confirmation)
        redirect("/login")
    rescue Exception => e
        display_error(db, e)
    end
end

# Displays all of the media stored in the database
#
# @see Model#get_all_media
get("/media") do
    return(slim(:"media/index", locals: { media: get_all_media(db), document_title: "Alla medier", db: db }))
end

# Displays the meny for creating mediaa
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
get("/media/new") do
    authorize_request(db, session[:user_id], "mod")
    slim(:"media/new", locals: { document_title: "Lägg till ett nytt medium", db: db })
end

# Creates a new medium in the database
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [String] params[:medium_name] the name of the to-be created medium
# @param [String] params[:medium_type] the type of the to-be created medium (song, book, etc.)
# @param [String] params[:medium_creation_date], the creation date of the to-be created medium using an acceptable format that can be passed into the Date.parse function.
# @param [String] params[:medium_authors] the authors of the to-be created medium. NOTE, the authors are the ones who created the original medium refered to in the website, not the people who posted it to the webiste.
# @param [String] params[:medium_genres] the genres of this medium
# @param [Hash, nil] params[:img_file] the uploaded image file through a HTML form, Is nil if no image has been uploaded
#
# @see Model#create_medium
post("/media") do
    authorize_request(db, session[:user_id], "mod")

    medium = {
        name: params[:medium_name],
        type: params[:medium_type],
        creation_date: params[:medium_creation_date],
        authors: params[:medium_authors],
        genres: params[:medium_genres],
        img_file: params[:medium_pic]
    }

    #File.join("./public/img/media", params[:media_pic][:filename])
    #File.write(path, File.read(params[:media_pic][:tempfile]))
    begin
        medium_id = create_medium(db, medium)
    rescue Exception => e
        return display_error(db, e)
    end
    redirect("media/#{medium_id}")
end

# Displays information about a certain medium stored in the database
#
# @param [String] params[:media_id] the id of the medium which information is displayed
#
# @see Model#media
get("/media/:media_id") do
    sought_id = params[:media_id].to_i
    sought_media = media(db, sought_id)
    puts(sought_media)

    return display_error(db, "The sought media could not be found") if sought_media.empty?

    slim(:"media/show", locals: { document_title: sought_media["name"], medium: sought_media, db: db })
end

# Display the edit page for the specifed medium
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [String] params[:medium_name] the name of the to-be created medium
# @param [String] params[:medium_type] the type of the to-be created medium (song, book, etc.)
# @param [String] params[:medium_creation_date] the creation date of the to-be created medium using an acceptable format that can be passed into the Date.parse function.
# @param [String] params[:medium_authors] the authors of the to-be created medium. NOTE, the authors are the ones who created the original medium refered to in the website, not the people who posted it to the webiste.
# @param [String] params[:medium_genres] the genres of this medium
# @param [String] params[:img_file] the uploaded image file through a HTML form
# @param [String] params[:medium_id] The ID of the medium to be edited
#
# @see Model#media
get("/media/:medium_id/edit") do
    authorize_request(db, session[:user_id], "mod")

    medium_id = params[:medium_id]
    medium = media(db, medium_id)

    display_error(db, "The medium ID specified does not exist.") if medium.empty?
    slim(:"media/edit", locals: { db: db, document_title: "Uppdatera mediumet", medium: medium })
end

# Updates a medium in the database
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [String] params[:medium_name] the new name of the medium
# @param [String] params[:medium_type] the new type of the medium (song, book, etc.)
# @param [String] params[:medium_creation_date] the new creation date of the medium using an acceptable format that can be passed into the Date.parse function.
# @param [String] params[:medium_authors] the new authors of the medium. NOTE, the authors are the ones who created the original medium refered to in the website, not the people who posted it to the webiste.
# @param [String] params[:medium_genres] the new genres of this medium
# @param [String] params[:img_file] the new uploaded image file for this medium through a HTML form
# @param [String] params[:medium_id] The ID of the medium to be edited
#
# @see Model#update_media
post("/media/:medium_id/update") do
    authorize_request(db, session[:user_id], "mod")

    medium_id = params[:medium_id]
    updated_medium = {
        name: params[:medium_name],
        type: params[:medium_type],
        creation_date: params[:medium_creation_date],
        authors: params[:medium_authors],
        genres: params[:medium_genres],
        img_file: params[:medium_pic]
    }

    #updated_medium.each do |attribute, value|
    #    print("ATTRIBUTE: #{attribute.class} VALUE: #{value.class}")
    #    if (!value || value == "") && attribute != :img_file
    #        puts("DISPLAYING PARAMETER ERROR")
    #        return display_error("Parameter #{attribute} is missing from the request or is nil")
    #    end
    #end

    begin
        update_medium(db, medium_id, updated_medium)
    rescue Exception => e
        return display_error(db, e)
    end

    redirect("/media/#{medium_id}")
end

# Deletes a specific medium from the database
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [String] params[:medium_id] the id of the medium that is going to be deleted
#
# @see Model#delete_medium
post("/media/:medium_id/delete") do
    authorize_request(db, session[:user_id], "mod")

    medium_id = params[:medium_id]
    begin
        delete_medium(db, medium_id)
        redirect("/media")
    rescue Exception => e
        display_error(db, e)
    end
end

# Finds all reviews beloumging to a media
#
# @param [Integer] params[:media_id] The ID of the media
#
# @see Model#get_all_reviews
get("/media/:media_id/reviews") do
    media_id = params[:media_id].to_i
    return display_error(db, "Mediumet existerar inte.") if !does_medium_exist(db, media_id)

    reviews = get_all_reviews(db, media_id)

    slim(:"review/index", locals: { document_title: "Reviews", reviews: reviews, db: db })
end

# Displays the menu for creating reviews
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [Integer] :media_id, The ID of the media
get("/media/:media_id/reviews/new") do
    authorize_request(db, session[:user_id], "guest")

    media_id = params[:media_id].to_i
    user_id = session[:user_id]
    if does_user_have_review(db, user_id, media_id)
        return display_error(db, "User does already have a review for this medium.")
    end

    slim(:"review/new", locals: { document_title: "Ny recension", media_id: media_id, db: db })
end

# Creates a review-row in the database and redirects user if successful
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [Integer] params[:media_id] The ID of the media
# @param [Integer] params[:review_rating] the review rating specified by the user
# @param [Integer] params[:review_desc] the review description specified by the user
#
# @see Model#review
post("/media/:media_id/reviews") do
    authorize_request(db, session[:user_id], "guest")

    media_id = params[:media_id].to_i
    review_rating = params[:review_rating].to_i
    review_desc = params[:review_desc]
    user_id = session[:user_id]

    begin
        new_review_id = create_review(db, media_id, user_id, review_rating, review_desc)
        redirect("/media/#{media_id}/reviews/#{new_review_id}")
    rescue Exception => e
        return display_error(db, e)
    end
    #slim(:"review/new", locals: { document_title: "Ny recension", media_id: media_id, db: db })
end

# Finds a specific review to a certain media
#
# @param [Integer] params[:media_id] The ID of the media
# @param [Integer] params[:review_id] The ID of the review
#
# @see Model#review
get("/media/:media_id/reviews/:review_id") do
    media_id = params[:media_id].to_i
    review_id = params[:review_id].to_i

    sought_review = review(db, review_id)

    if sought_review.empty? || sought_review["media_id"] != media_id
        return display_error(db, "Specified review is not found")
    end
    media_name = media_id_to_name(db, sought_review["media_id"])

    slim(
        :"review/show",
        locals: {
            document_title: "Review: #{media_name}",
            review: sought_review,
            media_name: media_name,
            user_author_name: user_ids_to_names(db, [sought_review["user_id"]]),
            date: Time.at(sought_review["creation_date"]).to_date,
            db: db
        }
    )
end

# Displays the edit menu for a certain review
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [Integer] params[:media_id] The ID of the media
# @param [Integer] params[:review_id] The ID of the review
#
# @see Model#review
get("/media/:media_id/reviews/:review_id/edit") do
    media_id = params[:media_id].to_i
    review_id = params[:review_id].to_i

    sought_review = review(db, review_id)

    if sought_review.empty? || sought_review["media_id"] != media_id
        return display_error("Mediumet hittades inte.")
    end

    authorize_request(db, session[:user_id], "user", sought_review["user_id"])

    return(
        slim(
            :"review/edit",
            locals: {
                document_title: "Redigera en recension",
                review: sought_review,
                media_id: media_id,
                db: db
            }
        )
    )
end

# Updates a certain review in the specified database
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [Integer] params[:media_id] The ID of the media
# @param [Integer] params[:review_id] The ID of the review
#
# @see Model#update_review
post("/media/:media_id/reviews/:review_id/update") do
    media_id = params[:media_id].to_i
    review_id = params[:review_id].to_i
    sought_review = review(db, review_id)

    authorize_request(db, session[:user_id], "user", sought_review["user_id"])
    begin
        if !update_review(
                  db,
                  media_id,
                  review_id,
                  { edited_review_desc: params[:review_desc], edited_review_rating: params[:review_rating] }
              )
            return display_error("Recensionen hittades inte.")
        end
    rescue Exception => e
        return display_error(db, e)
    end

    redirect("/media/#{media_id}/reviews/#{review_id}")
end

# Deletes an review and redirects to /review
#
# @param [Number, Nil] session[:user_id] the id of a potential logged in user
# @param [Integer] params[:media_id] The ID of the media
# @param [Integer] params[:review_id] The ID of the to be deleted review
#
# @see Model#delete_review
post("/media/:media_id/reviews/:review_id/delete") do
    media_id = params[:media_id].to_i
    review_id = params[:review_id].to_i

    sought_review = review(db, review_id)
    authorize_request(db, session[:user_id], "user", sought_review["user_id"])

    if !delete_review(db, media_id, review_id)
        return(
            slim(:"error", locals: { document_title: "404", error_message: "The review specified is not found." })
        )
    end

    redirect("/media/#{media_id}/reviews")
end
