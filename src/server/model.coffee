redis = require "redis"
client = redis.createClient()

# redis.debug_mode = true

client.on "error", (err) ->
    console.log "Error ", err
    return

loadActivities = (aids, callback) ->
    activities = []
    if not aids.length
        callback null, activities
    n = 0
    for aid in aids
        key = 'aid:' + aid + ':activity'
        client.hgetall key, (err, activity) ->
            activity.aid = aids[n]
            activities.push activity
            if ++n is aids.length
                callback err, activities
            return
    return

exports.getActivities = (key, start, stop, callback) ->
    n = 0
    activities = []
    query = [
        key,
        '+inf', '-inf',
        'limit', start, stop
    ]
    client.zrevrangebyscore query, (err, aids) ->
        loadActivities aids, callback
        return
    return

exports.getUserActivities = (uid, start, stop, callback) ->
    key = 'uid:' + uid + ':aids'
    exports.getActivities key, start, stop, callback
    return

exports.getAllActivities = (start, stop, callback) ->
    key = 'activities:aids'
    exports.getActivities key, start, stop, callback
    return

exports.addActivity = (activity) ->
    console.log activity
    uid = activity.uid
    tag = activity.tag
    start = activity.start
    # Increments and get the activities counter
    client.incr 'global:aid', (err, aid) ->
        # Create the activity
        client.hmset 'aid:' + aid + ':activity', activity
        # Add it to activities lists
        client.zadd 'uid:' + uid + ':aids', start, aid
        client.zadd 'activities:aids', start, aid
        # Update statistics for input autocompletion
        client.zincrby 'uid:' + uid + ':tags', 1, tag
        # Publish messages to report the new activity
        client.publish 'pubsub', 'An activity has been created'
        client.publish 'newaid', aid
        return
    return

exports.delActivity = (aid, callback) ->
    client.hgetall 'aid:' + aid + ':activity', (err, activity) ->
        uid = activity.uid
        tag = activity.tag
        start = activity.start
        client.del 'aid:' + aid + ':activity', (err, res) ->
            client.zrem 'uid:' + uid + ':aids', aid, (err, res) ->
                client.zrem 'activities:aids', aid, (err, res) ->
                    key = 'uid:' + uid + ':tags'
                    client.zincrby key, -1, tag, (err, res) ->
                        client.publish 'pubsub', 'An activity has been removed'
                        callback err
                        return
                    return
                return
            return
        return
    return

exports.stopActivity = (aid, timestamp, callback) ->
    key = 'aid:' + aid + ':activity'
    client.hset key, 'stop', timestamp, callback
    return

exports.addUser = (user, callback) ->
    # Increments and get the users counter
    client.incr 'global:uid', (err, uid) ->
        # Create the user
        client.hmset 'uid:' + uid + ':user', user, (err, res) ->
            client.set 'username:' + user.name + ':uid', uid, (err, res) ->
                callback uid
                return
            return
        return
    return

exports.getUserId = (username, callback) ->
    # TODO Call callback directly without creating an anonymous function
    client.get 'username:' + username + ':uid', callback
    return

exports.getUserPassword = (uid, callback) ->
    client.hget 'uid:' + uid + ':user', 'password', callback
    return

exports.getUserEmail = (uid, email, callback) ->
    client.hget 'uid:' + uid + ':user', 'email', callback
    return

exports.changeUserName = (oldUsername, newUsername) ->
    getUserId oldUsername, (err, uid) ->
        client.del 'username:' + oldUsername + ':uid'
        client.set 'username:' + newUsername + ':uid', uid
        client.hset 'uid:' + uid + ':user', 'name', newUsername
        return
    return

exports.setUserPassword = (uid, password) ->
    client.hset 'uid:' + uid + ':user', 'password', password
    return

exports.getTags = (uid, callback) ->
    query = [
        'uid:' + uid + ':tags',
        '+inf', '-inf',
        'limit', 0 , 6
    ]
    client.zrevrangebyscore query, callback
    return

exports.getTagScore = (uid, tag, callback) ->
    client.zscore 'uid:' + uid + ':tags', tag, callback
    return

exports.countTag = (uid, tag, start, end, callback) ->
    key = 'uid:' + uid + ':aids'
    count = 0
    client.zrangebyscore key, start, end, (err, aids) ->
        if aids? and aids.length
            loadActivities aids, (err, activities) ->
                for activity in activities
                    if activity.tag is tag
                        count++
                callback err, count
                return
        else
            callback err, count
        return
    return

exports.setTokenUser = (token, user) ->
    key = 'token:' + token + ':user'
    client.hmset key, user
    client.expire key, 60 * 60 * 12
    return

exports.getTokenUser = (token, callback) ->
    key = 'token:' + token + ':user'
    client.exists key, (err, exists) ->
        if exists
            client.hgetall key, (err, user) ->
                # Delete the token and return the user
                client.del key
                callback err, user
                return
        else
            callback err, null
        return
    return
