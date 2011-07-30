
# Module dependencies.

express = require 'express'

#$ = require 'jquery'

redis = require 'redis'
client = redis.createClient()

#io = require 'socket.io'
io = require('socket.io').listen 9000

RedisStore = require('connect-redis') express

app = module.exports = express.createServer()

Email = require('email').Email

# Form validator
check = require('validator').check
sanitize = require('validator').sanitize

# Crypto
require 'joose'
require 'joosex-namespace-depended'
require 'hash'

random = require 'mersenne'
    
model = require './lib/model'
time = require './lib/time'

# Configuration

sessionOptions =
    secret: "oodei1sohs7kiTi8Eifeikayiu1Ge5Et"
    store: new RedisStore
    cookie: maxAge: 30 * 24 * 60 * 60 * 1000 


app.configure ->
    app.set 'views', __dirname + '/views'
    app.set 'view engine', 'jade'
    app.use express.bodyParser()
    app.use express.cookieParser() 
    app.use express.session sessionOptions
    app.use express.methodOverride() 
    app.use app.router
    app.use express.static __dirname + '/public'
    return

app.configure 'development', -> 
    app.use express.errorHandler dumpExceptions: true, showStack: true  
    return

app.configure 'production', ->
    app.use express.errorHandler  
    return

io.configure 'production', ->
    io.enable 'browser client etag'
    io.set 'log level', 1
    io.set 'transports', [
        'websocket',
        'flashsocket',
        'htmlfile',
        'xhr-polling',
        'jsonp-polling'
    ]
    return

io.configure 'development', ->
    io.set 'transports', ['websocket']
    io.set 'log level', 1
    return

randomGenerator = (n) ->
    res = []
    while res.length < n
        c = random.rand 123
        if (47 < c < 58) or (64 < c < 91) or (96 < c < 123)
            res.push String.fromCharCode c
    return res.join ''

configuration =
    title: 'Dia.li (fe) log'
    scripts: [
        '/javascripts/jquery-1.6.2.min.js',
        '/javascripts/jquery-ui-1.8.14.custom.min.js',
        '/javascripts/socket.io.min.js',
        '/javascripts/diali.js'
    ]
    styles: [
        '/stylesheets/screen.css',
        '/stylesheets/jquery-ui-1.8.14.custom.css',
    ]

loadDefaultConfig = ->
    config =
        title: configuration.title
        scripts: (script for script in configuration.scripts)
        styles: (style for style in configuration.styles)
    return config

# Routes

app.all '*', (req, res, next) ->
    log = [
        req.client.remoteAddress,
        '-',
        '-',
        '[' + time.toISO((new Date()).getTime()) + ']',
        '"' + req.method + ' ' + req.url + '"',
        '200',
        '-',
        '"' + req.headers.referer + '"',
        '"' + req.headers['user-agent'] + '"'
    ]
    console.log log.join ' '

    req.options = loadDefaultConfig()
    #req.options.homepage = false # TODO find out why we need this here
    #delete req.options.message
    if req.session? and req.session.user?
        req.options.user = req.session.user
    #else
    #    #if req.session?
    #    #    #req.session.regenerate 
    #    delete req.options.user
    
    req.options.layout = not req.xhr
    return next()

app.all '/user/*', (req, res, next) ->
    if req.options.user?
        next()
    else
        res.statusCode = 403
        req.options.title = 'Access Forbidden!'
        req.options.message = 
            "You cannot acces '<a href=\"\">" + req.url + 
            "</a>' without <a href=\"/login\">login</a> first."
        res.render 'error', req.options
     return

app.post '/*?', (req, res, next) ->
    #Validator = require('validator').Validator
    # req.validator = new Validator()
    #error = (msg) ->
    #    console.error 'Fail validation: ' + msg
    #    res.redirect 'back'
    #    return
    return next()

app.get '/', (req, res) ->
    req.options.homepage = true
    res.render 'index', req.options
    return

app.get '/activities/:start?/?:stop?', (req, res) ->
    start = if req.params.start? then req.params.start else 0
    stop = if req.params.stop? then req.params.stop else 19
    model.getAllActivities start, stop, (err, activities) ->
        if not req.xhr
            if activities.length is 0
                req.options.message = "No activities yet."
            req.options.banner = true
        else
            delete req.options.banner
            delete req.options.message
        
        # Rewrite activities from the model to fit the view
        for activity, i in activities
            start = activity.start
            activity.startingDate = time.toISO start
            activity.startingTime = time.timesince start
            activities[i] = activity
        req.options.activities = activities
        
        req.options.layout = not req.xhr
        res.render 'activities', req.options
    return

app.get '/user/activity/list/:start?/?:stop?', (req, res) ->
    start = if req.params.start? then req.params.start else 0
    stop = if req.params.stop? then req.params.stop else 19
    uid = req.options.user.id
    #console.log "GET activities from '%d' to '%d'", start, stop
    model.getUserActivities uid, start, stop, (err, activities) ->
        if not req.xhr
            if activities.length is 0
                req.options.message = "No activities yet."
            req.options.banner = true
        else
            delete req.options.banner
            delete req.options.message
        
        # Rewrite activities from the model to fit the view
        for activity, i in activities
            start = parseInt activity.start
            activity.startingDate = time.toISO start
            activity.startingTime = time.timesince start
            stop = parseInt activity.stop
            activity.stoppingDate = 
                if stop then time.toISO stop else ''
            activity.stoppingTime = 
                if stop then time.timesince stop else ''
            activity.duration = 
                if stop then time.timesince start, stop, true else ''
            activities[i] = activity
        req.options.activities = activities
        req.options.layout = not req.xhr
        res.render 'user/activity/list', req.options
        return
    return

app.get '/user/tags/:tag?', (req, res) ->
    tag = req.params.tag
    req.options.scripts.push '/javascripts/jquery.flot.min.js'
    model.getTagScore req.options.user.id, tag, (err, score) ->
        req.options.tag = tag
        req.options.score = score
        res.render 'user/tag/info', req.options
        return
    return

app.get '/user/charts/tag.json', (req, res) ->
    res.contentType 'application/json'
    uid = req.session.user.id
    tag = req.param 'tag', ''
    now = (new Date()).getTime()
    day = 24 * 60 * 60 * 1000
    serie = []
    n = 30
    for i in [30..0]
        start = now - i * day
        stop = now - (i - 1) * day
        model.countTag uid, tag, start, stop, (err, count) ->
            serie.push [ now - n * day, count ]
            #console.log 'Got n(%d) = %d', n, count
            if n-- is 0
                #console.log 'Sending JSON'
                res.send JSON.stringify serie
            return
    return

app.post '/user/activity/new', (req, res) ->
    activity = req.body.activity
    
    tag = sanitize(activity.tag).xss()
    minutes = sanitize(activity.minutes).toInt()
    hours = sanitize(activity.hours).toInt()
    period = sanitize(activity.period).xss()
    timeAgo = sanitize(activity.time).toInt()

    # Generate activity date
    date = new Date()
    switch activity.type
        when 'at'
            date = new Date()
            date.setMinutes minutes
            date.setHours(hours + (if period is 'p.m.' then 12 else 0))
            if date > new Date()
                date.setDate date.getDate() - 1
        when 'ago'
            date.setMinutes date.getMinutes() - timeAgo

    # Saving activity
    model.addActivity
        uid: req.session.user.id
        tag: tag
        start: date.getTime()
        stop: 0
    
    req.options.tag = tag
    req.options.date = date
    req.options.time = time.timesince date.getTime() 
    res.render 'user/activity/new', req.options
    return

app.post '/user/activity/stop', (req, res) ->
    activity = req.body.activity
    aid = activity.aid

    # Check activity.uid = user.uid

    # Generate activity date
    date = new Date()
    switch activity.type
        when 'at'
            date = new Date()
            date.setMinutes activity.minutes
            date.setHours (parseInt activity.hours) +
                          (if activity.period is 'p.m.' then 12 else 0)
            
            if  date > new Date()
                date.setDate date.getDate() - 1
            
        when 'ago'
            date.setMinutes date.getMinutes() - activity.time
    
    # Saving activity
    model.stopActivity aid, date.getTime(), (err) ->
        #console.log 'Activity Stopped'
        if not req.xhr
            res.redirect 'back'
        else
            model.getActivityDuration aid, (err, duration) ->
                res.send time.timedelta duration
                return
        return
    return

app.get '/user/activity/del/:aid', (req, res) ->
    aid = req.params.aid
    if aid?
        model.delActivity aid, (err) ->
            res.redirect 'back'
            return
    return

app.get '/user/tag.json', (req, res) ->
    res.contentType 'application/json'
    term = req.param 'term', ''
    if term isnt ''
        model.getTags req.session.user.id, (err, tags) ->
            matches = (tag for tag in tags when ~tag.indexOf term)
            tagsJSON = JSON.stringify matches
            res.send tagsJSON
            return
    else
        res.send JSON.stringify []
    return


app.get '/register', (req, res) ->
    req.options.layout = not req.xhr
    res.render 'register', req.options
    return

app.post '/register', (req, res) ->
    user = req.body.user
    if user?
        # Validate Form
        try
            check(user.name).is('^[a-zA-Z0-9_ -]{3,32}$')
            check(user.email).isEmail() 
        catch e
            console.log e
            res.redirect 'back'
            return

        # Add user
        # We are only storing a hash of his username
        hashedUsername = Hash.sha256 user.name
        model.getUserId hashedUsername, (err, uid) ->
            if uid?
                console.log 'User exist, cancel registering'
                res.redirect 'back'
            else
                password = randomGenerator 12
                # And a hash of a generated password
                hashedPassword = Hash.sha256 password
                newUser =
                    name: hashedUsername
                    email: Hash.sha256 user.email
                    password: Hash.sha256 password
                
                model.addUser newUser, (uid) ->
                    # Send the password to the user by email
                    mail = new Email
                        from: "Dia.li <robot@dia.li>"
                        to: user.email
                        subject: "[Dia.li] Registration"
                        body: "Hi " + user.name + ",\n\n" +
                              "Thank you for registering to Dia.li!\n\n" +
                              "Your password is: " + password + "\n\n" +
                              "Thanks,\n\n" +
                              "The Dia.li Robot"

                    mail.send (err) ->
                        console.error err

                    # We dont need the email anymore
                    delete user.email

                    # But we need is uid
                    user.id = uid

                    # Login user
                    req.session.user = user
                    res.redirect '/'
    else
        res.redirect 'back'
    return

app.get '/login', (req, res) ->
    req.options.layout = not req.xhr
    res.render 'login', req.options
    return

app.post '/login', (req, res) ->
    user = req.body.user
    if user?
        # Validate Form
        try
            check(user.name).is('^[a-zA-Z0-9_ -]{3,32}$')
            check(user.password).is('^[a-zA-Z0-9]{12}$')
        catch e
            console.log e
            res.redirect 'back'
            return

        # user:hash username -> hash password
        key = 'user:' + Hash.sha256 user.name
        client.get key, (err, value) ->
            if value is Hash.sha256 user.password
                # Create the session
                # But dont store the clear text password in it
                delete user.password
                req.session.user = user
                console.log "Correct password for user '" + user.name + "'"
            else
                console.log "Wrong password for user '" + user.name + "'"
            res.redirect 'back'
            return
    else
        res.redirect 'back'
    return

app.get '/logout', (req, res) ->
    console.log 'Destroying session.'
    req.session.destroy (err) ->
        console.error 'Cannot destroy session.'
        return
    delete req.options.user
    res.redirect 'back'
    return

app.get '/reset-password/:token?', (req, res) ->
    token = req.params.token
    if token?
        model.getTokenUser token, (err, user) ->
            if user?
                password = randomGenerator 12

                # And a hash of a generated password
                hashedPassword = Hash.sha256 password
                delete password

                model.setUserPassword user.id, hashedPassword 
                mail = new Email
                    from: "Dia.li <robot@dia.li>"
                    to: user.email
                    subject: "[Dia.li] Password successfully reseted"
                    body: "Hi " + user.name + ",\n\n" +
                          "Your new password is: " + password + "\n\n" +
                          "Thanks,\n\n" +
                          "The Dia.li Robot"
                
                delete user.email

                mail.send (err) ->
                    console.error err
                    return
                
                # Login user 
                req.session.user = user
                res.redirect '/'
            
            else
                res.statusCode = 404
                req.options.title = '404'
                req.options.message = 'Not found'
                res.render 'error', req.options
            return
    else
        res.render 'reset-password', req.options
    return

app.post '/reset-password', (req, res) ->
    # We need the username to find the uid, and the email
    # address to check it against the database and to be
    # sure that we are not sending a new password request
    # link to a wrong email.
    # We could only use the email but this will require a
    # one to one relationship with a user account.

    user = req.body.user
    if user?
        # Validate Form
        try
            check(user.name).is('^[a-zA-Z0-9_ -]{3, 32}$')
            check(user.email).isEmail()
        catch e
            console.log e
            res.redirect 'back'
            return

        hashedUsername = Hash.sha256 user.name
        model.getUserId hashedUsername, (err, uid) ->
            user.id = uid
            hashedEmail = Hash.sha256 user.email    
            model.getUserEmail uid, hashedEmail, (err, email) ->
                if email is hashedEmail
                    token = Hash.sha256(randomGenerator 12)
                    model.setTokenUser token, user

                    # Send the new password request link to the user by email
                    link = 'http://beta.dia.li/reset-password/' + token
                    console.log link
                    mail = new Email
                        from: "Dia.li <robot@dia.li>"
                        to: user.email
                        subject: "[Dia.li] Request for reseting your password"
                        body: 'Hi ' + user.name + ', \n\n' +
                              'You requested a reset of your password, if that ' +
                              'is what you want, then the following link will ' +
                              'do just that: \n\n' + 
                              link + '\n\n' +
                              'Thanks,' +
                              'The Dia.li robot'
                    
                    mail.send (err) ->
                        console.error err
                        return
                
                    req.options.banner = true
                    req.options.message = "You will soon receive a password reset" +
                                          " link at '" + user.email + "'."
                    res.render 'message', req.options          
                return
            return
    return

app.listen 3000
console.log "Express server listening on port %d in %s mode", 
    app.address().port, app.settings.env

io.sockets.on 'connection', (socket) ->
    subscribe = redis.createClient() 
    subscribe.subscribe 'pubsub'

    subscribe.on "message", (channel, message) ->
        socket.send message
        return

    socket.on 'message', (message) ->
        return
    
    subscribe.on 'connect', (message) ->
        socket.broadcast.send 'Someone just connected!'
        return

    socket.on 'disconnect', ->
        subscribe.quit()
        return

    return
