$ = require('jquery')

units =
    second: 1000
    minute: 60
    hour: 60
    day: 24
    year: 365

exports.timedelta = (duration) ->
    end = (new Date()).getTime()
    start = end - duration
    return exports.timesince(start, end, true)

exports.timesince = (start, end = (new Date()).getTime(), duration = false) ->
    delta = end - start
    if delta < 0 # The event ended before it started
        if duration
            return 'backward in time'
        else
            return 'at some point in the past'
    else if delta < 1000 # The delta time is too short
        if duration
            return delta + ' milliseconds'
        else
            return 'just now'
    res = []
    quotient = delta
    for key, value of units
        reminder = quotient % value
        quotient = Math.floor(quotient / value)
        if quotient is 0
            break
        res = [ quotient, ' ', key ]
        if (quotient > 1)
            res.push('s')
        if tmpKey? and reminder > 0
            res = res.concat([ ' and ', reminder, units.tmpKey, ' ', tmpKey ])
            if reminder > 1
                res.push('s')
        tmpKey = key
    if duration
        res.unshift('for ')
    else
        res.push(' ago')
    return res.join('')

exports.toISO = (timestamp) ->
    date = new Date(parseInt(timestamp))
    month = date.getMonth() + 1
    if month < 10
        month = '0' + month
    day = date.getDate()
    if day < 10
        day = '0' + day
    hour = date.getHours()
    if hour < 10
        hour = '0' + hour
    minute = date.getMinutes()
    if minute < 10
        minute = '0' + minute
    second = date.getSeconds()
    if second < 10
        second = '0' + second
    millisecond = date.getMilliseconds()
    if millisecond < 10
        millisecond = '0' + millisecond
    if millisecond < 100
        millisecond = '0' + millisecond
    tz = date.getTimezoneOffset()
    tzSign = if tz < 0 then '-' else '+'
    tzHour = Math.floor(Math.abs(tz) / 60)
    if tzHour < 10
        tzHour = '0' + tzHour
    tzMinute = Math.abs(tz) % 60
    if tzMinute < 10
        tzMinute = '0' + tzMinute
    tz = tzSign + tzHour + ':' + tzMinute
    
    return [
        date.getFullYear(), '-'
        month, '-'
        day, 'T'
        hour, ':'
        minute, ':'
        second, '.'
        millisecond
        tz
    ].join('')
