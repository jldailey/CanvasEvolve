
$.log "waiting..."
$(document).ready ->
	$.log "setting up..."
	imageDistance = (a, b) ->
		sum = 0|0
		for i in [0...Math.min a.length, b.length] by 1
			x = a[i]|0
			y = b[i]|0
			z = (x - y)|0
			sum += Math.pow(z,2)|0
		Math.sqrt(sum)|0

	# These will be the 3 image data blocks that we track
	original = best = current = null
	stopped = false

	# The dimensions of the image we will learn
	width = 320
	height = 240

	# The canvas we will draw the current guess on
	canvas = $.synth("canvas.stop").prependTo("#container")
	context = canvas.first().getContext('2d')
	context.clear = (c = 'black') ->
		@fillStyle = c
		@fillRect 0,0,width,height
	randomPoint = -> $($.random.integer(0, width), $.random.integer(0,height))
	randomColor = -> "rgba(#{$.random.integer 0,256},#{$.random.integer 0,256},#{$.random.integer 0,256}, .5)"
	randomTriangle = ->
		offset = randomPoint().scale(.85)
		[ randomPoint().scale(.15).plus(offset),
			randomPoint().scale(.15).plus(offset),
			randomPoint().scale(.15).plus(offset)
		]
	boundingBox = (triangle) ->
		X = $(triangle).select('0')
		Y = $(triangle).select('1')
		minX = X.reduce(Math.min)
		maxX = X.reduce(Math.max)
		minY = Y.reduce(Math.min)
		maxY = Y.reduce(Math.min)
		return [minX, minY, maxX, maxY]

	context.drawRandomTriangle = ->
		corners = randomTriangle()
		@beginPath()
		@moveTo corners[0]...
		@lineTo corners[1]...
		@lineTo corners[2]...
		@lineTo corners[0]...
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
				.attr('src', URL.createObjectURL stream)
				.prependTo("body")
				.first()
			video.addEventListener 'loadedmetadata', (evt) ->
				$.log "on loadedmetadata", evt
				video.play()
				canvas.attr { width, height }
				context = canvas.first().getContext('2d')
				$.delay 1000, ->
					$.log "Drawing to canvas", video
					video.pause()
					context.drawImage video, 0, 0, width, height
					cb null, video
					$("video").remove()
		navigator.getUserMedia { video: true }, onVideo, (err) -> cb err, null

	# Set up the original from an image of the mona lisa
	setupImage = (cb) ->
		$.log "Using fallback image..."
		$.Promise.image("monalisa.jpg").wait (err, image) ->
			return cb(err, null) if err?
			$(image).attr({width:320,height:240}).prependTo("#container")
			{width, height} = image
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
		context.drawRandomTriangle()
		$.delay 30, ->
			# big optimization?
			# only get the image data for the area that the triangle affected
			# and see if that area improved
			# requires two calls to getImageData (since we couldn't have an original.data for every smaller area)
			# but it would mean that performance would be constant no matter how big the canvas,
			# and possibly faster in all cases where the image size is not-tiny
			current = context.getImageData 0, 0, width, height
			current.dist = imageDistance current.data, original.data
			if current.dist < best.dist
				best = current
			context.putImageData best, 0, 0
			if best.dist > 100 and not stopped
				setTimeout frame, 0

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
		setTimeout frame, 0
		last_frame = $.now

	do setupStage = ->
		setupVideo (err, video) ->
			$.log "setupVideo ->", err, video
			if err? then setupImage (err, image) ->
				$.log "setupImage ->", err, image
				unless err? then stageReady()
				$("img").hide()
			else stageReady()

	setGradient = (selector, pct, opts) ->
		opts = $.extend({ fg: 'green', bg: 'white' }, opts)
		node = $(selector)
		text = "linear-gradient(right, #{opts.fg} 0%, #{opts.fg} #{pct}%, #{opts.bg} #{pct}%, #{opts.bg} 100%)"
		for prefix in ["-webkit-", "-moz-", "-o-","-ms-"]
			node.css("background-image", prefix + text)
		node.css("background-image", text.replace(/right,/,'to right,'))
		null

