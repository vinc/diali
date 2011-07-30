$(document).ready ->
    # Set tag input default value
    inputTag = 'input[name="activity[tag]"]'
    inputTagDefault = 'typing in this box'
    inputTagModified = false
    inputTagColor = $(inputTag).css 'color'
    $(inputTag).val inputTagDefault
    $(inputTag).focusin ->  
        if not inputTagModified 
            $(this).css 'color', '#999'
        return
    
    $(inputTag).focusout ->
        if not inputTagModified 
            $(this).css 'color', inputTagColor
        return
    
    $(inputTag).keydown ->
        if not inputTagModified 
            inputTagModified = true
            $(this).val ''
            $(this).css 'color', inputTagColor
        return
    
    $(inputTag).bind 'paste', -> 
        if not inputTagModified 
            inputTagModified = true
            $(this).val ''
            $(this).css 'color', inputTagColor
        return
    
    $('input[autofocus]').trigger 'focusin'

    # Define autocomplete JSON source
    $(inputTag).autocomplete  source: '/user/tag.json' 
    
    # Hide unnecessary select
    selectTime = (select) ->
        ago = select.parent().children('.ago')
        at = select.parent().children('.at')
        switch select.val()
            when 'now'
                ago.hide()
                at.hide()
            when 'ago'
                ago.show()
                at.hide()
            when 'at'
                ago.hide()
                at.show()
        return
    
    $('.time').change ->
        selectTime $(this) 
        return
    
    $('#homepage #userbox').hide()

    showUserBox = ->
        $('#homepage #userbox').delay(500).fadeIn 1500
        return
    
    $(document).keypress showUserBox
    $(document).bind 'mousemove', showUserBox

    activityCounter = 0
    $('#new-activity').submit ->
        tag = $(inputTag).val()
        if tag is ''
            return false
        
        data = 'activity[tag]=' + tag
        fields = ['time', 'type', 'hours', 'minutes', 'period']
        for field in fields
            field = 'activity[' + field + ']'
            data += '&' + field + '=' + $('select[name="' + field + '"]').val()
        
        $('input[name="activity[tag]"]').autocomplete 'close'
        i = ++activityCounter
        content = $ '#message'
        content.append '<p id="message-activity-' + i + '">Saving...</p>'
        $.ajax 
            type: "POST"
            url: "/user/activity/new"
            data: data
            success: (activity) ->
                if activity?
                    # Display saving message
                    $('#message-activity-' + i).html('Saved!')
                        .delay(3000)
                        .fadeOut 1500, ->
                            $('#message-activity-' + i).remove()
                            return
                else
                    $('#message-activity-' + i).html 'Something went wrong!'
                # Reset form
                $(inputTag).val ''
                $('.ago').hide()
                $('.at').hide()
                for field in fields
                    field = 'activity[' + field + ']'
                    field = 'select[name="' + field + '"]'
                    $(field + ' option:first').attr 'selected', 'selected'
                return
            statusCode:
                403: ->
                    $('#message-activity-' + i).html 'You need to ' + 
                        '<a href="/register">register</a> or ' + 
                        '<a href="/login">login</a> first!'
                    return
        return false
    

    # Infinite activity listing
    limit = 19
    n = limit + 1
    path = location.pathname.split "/"
    isListing = (path[1] is 'activities') or
                (path[2] is 'activity' and path[3] is 'list')
    isLoadingMoreActivities = false
    $(window).scroll ->
        dh = $(document).height()
        wh = $(window).height()
        isNearBottom = $(window).scrollTop() > (dh - wh - 400)
        if isListing and isNearBottom and not isLoadingMoreActivities 
            isLoadingMoreActivities = true
            $.get location.pathname + '/' + n + '/' +  (n + limit), 
                (activities) -> 
                    $('#content').append activities
                    n += limit + 1
                    isLoadingMoreActivities = false
                    return
        return

    # Socket.io
    socket = io.connect 'http://beta.dia.li:9000'
    content = $('#events')

    socket.on 'connect', ->
        return
    
    messageCounter = 0
    socket.on 'message', (message) ->
        j = ++messageCounter
        content.prepend '<p id="message-' + j + '">' + message + '</p>'
        $('#message-' + j).delay(3000).fadeOut 1500, ->
            $('#message-' + j).remove()
            return
        return
               
    socket.on 'disconnect', -> 
        console.log 'disconnected'
        content.html "<p>Disconnected!</p>"
        return

    # Activities list

    # Stop activity
    $('.stop-activity').submit ->
        form = $ this
        key = 'activity[aid]'
        val = $('input[name="' + key + '"]', this).val()
        data = [key + '=' + val]
        for field in ['time', 'type', 'hours', 'minutes', 'period']
            key = 'activity[' + field + ']'
            val = $('select[name="' + key + '"]', this).val()
            data.push key + '=' + val
        $.post '/user/activity/stop', data.join('&'), (duration) ->
            activity = form.parent()
            form.remove()
            msg = 'and you did it for ' + duration + '.'
            #msg = 'and you just stopped it.'
            html = '<p class="stop-activity">' + msg + '</p>'
            activity.append(html)
            return
        return false
    # Delete activity
    $(".delete-activity").click -> 
        #e.preventDefault 
        if confirm "This activity will be permanently deleted." 
            link = $ this
            url = link.attr "href"
            $.get url, (data) -> 
                # Remove the activity
                activity = link.parent().parent()
                activity.fadeOut 500, ->
                    $(this).remove()
                    return
                return
        return false
