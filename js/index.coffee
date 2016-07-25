
console.log "waiting..."
$(document).ready ->
	console.log "setting up..."
	imageDistance = (a, b) ->
		sum = 0
		for i in [0...Math.min a.length, b.length] by 1
			sum += Math.pow (a[i] - b[i]), 2
		Math.sqrt(sum)

	# These are the 3 imageData objects that we track:
	original = best = current = null

	# A flag to stop improving the best image
	stopped = false

	# The dimensions of the image we will learn
	size = Math.min(window.innerWidth, window.innerHeight)
	[ width, height ] = [ size, size ]

	video = null
	triangleCount = trianglesKept = 0

	# The canvas we will draw the current image on
	canvas = $.synth("canvas.stop").prependTo("body")
	context = canvas.first().getContext('2d')
	# Extend our drawing context
	context.clear = (c = 'black') ->
		@fillStyle = c
		@fillRect 0,0,width,height
	randomPoint = -> $ $.random.integer(0, width), $.random.integer(0,height)
	randomColor = -> "rgba(#{$.random.integer 0,256},#{$.random.integer 0,256},#{$.random.integer 0,256}, .5)"

	scaleBalance = [.80, .20]
	context.randomTriangle = ->
		n = $.random.real(.50, .97)
		scaleBalance = [n, 1 - n]
		triangleCount += 1
		offset = randomPoint().scale(scaleBalance[0])
		@beginPath()
		@moveTo (start = randomPoint().scale(scaleBalance[1]).plus offset)...
		@lineTo randomPoint().scale(scaleBalance[1]).plus(offset)...
		@lineTo randomPoint().scale(scaleBalance[1]).plus(offset)...
		@lineTo start...
		@closePath()
		@fillStyle = randomColor()
		@fill()

	# Set up the original from a webcam source
	setupVideo = (cb) ->
		navigator.getUserMedia \
			or= navigator.webkitGetUserMedia \
			or navigator.mozGetUserMedia \
			or navigator.msGetUserMedia
		unless navigator.getUserMedia
			return cb "unsupported", null
		onVideo = (stream) ->
			$.log "onVideo", stream
			video = $.synth("video[width=#{width}][height=#{height}]")
				.css({ width: $.px(width), height: $.px(height) })
				.attr('src', URL.createObjectURL stream)
				.prependTo("body")
				.first()
			video.addEventListener 'loadedmetadata', (evt) ->
				$.log "on loadedmetadata", evt
				video.play()
				canvas.attr({ width, height }).css({
					width: $.px(width)
					height: $.px(height)
				})
				context = canvas.first().getContext('2d')
				$.delay 1000, ->
					$.log "Drawing to canvas", video
					# video.pause()
					context.drawImage video, 0, 0, width, height
					cb null, video
					# $("video").remove()
		onError = (err) -> cb err, null
		navigator.getUserMedia { video: true }, onVideo, onError

	# Set up the original from an image of the mona lisa
	setupImage = (cb) ->
		$.Promise.image("earring.jpg").wait (err, image) ->
			return cb(err, null) if err?
			$(image).attr({ width, height }).prependTo("body")
			canvas.attr { width, height }
			context.drawImage image, 0, 0, width, height
			cb null, image

	runtime = 0
	last_frame = 0
	frame = ->
		return if stopped
		dt = $.now - last_frame
		runtime += dt
		last_frame += dt
		context.randomTriangle()
		do ->
			current = context.getImageData 0, 0, width, height
			current.dist = imageDistance current.data, original.data
			if current.dist < best.dist
				best = current
				window.setProgress best.dist, original.dist
				trianglesKept += 1
			context.putImageData best, 0, 0
			if best.dist > 100 and not stopped
				setTimeout frame, 0
	
	replaceOriginalFromVideo = ->
		return unless video?
		_canvas = $.synth("canvas.offstage").attr({ width, height })
		_context =  _canvas.first().getContext('2d')
		_context.drawImage video, 0, 0, width, height
		original = _context.getImageData 0, 0, width, height
		original.dist = best.dist = imageDistance best.data, original.data

	stageReady = ->
		$.log "Stage is ready."
		original = context.getImageData 0, 0, width, height
		context.clear('white')
		best = current = context.getImageData 0,0,width,height
		original.dist = best.dist = imageDistance(best.data, original.data)
		$(".stop").click ->
			stopped = !stopped
			if not stopped
				setTimeout frame, 0
				last_frame = $.now
			else
				$("#progress").text("Paused")
				# trianglesKept = triangleCount = 0
		setTimeout frame, 0
		last_frame = $.now

	do setupStage = ->
		setupVideo (err, video) ->
			$.log "setupVideo ->", err, video
			if err? then setupImage (err, image) ->
				$.log "setupImage ->", err, image
				unless err? then stageReady()
				$("img").hide()
			else
				canvas.first().scrollIntoView()
				# $.interval 1000, replaceOriginalFromVideo
				stageReady()

	setGradient = (selector, pct, opts) ->
		opts = $.extend({ fg: 'green', bg: 'white' }, opts)
		node = $(selector)
		text = "linear-gradient(right, #{opts.fg} 0%, #{opts.fg} #{pct}%, #{opts.bg} #{pct}%, #{opts.bg} 100%)"
		for prefix in ["-webkit-", "-moz-", "-o-","-ms-"]
			node.css("background-image", prefix + text)
		node.css("background-image", text.replace(/right,/,'to right,'))
		null

	verbose = false
	$("#progress").click ->
		verbose = !verbose
		if not verbose
			$("#progress").text("")

	window.setProgress = (cur, max) ->
		return
		pct = 100 * (max - cur) / max
		node = $("#progress")
		setGradient(node, pct)
		m = (trianglesKept / triangleCount).toFixed(4)
		if verbose
			node.text("Painting...")

