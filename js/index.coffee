
console.log "waiting..."
$(document).ready ->
	console.log "setting up..."
	imageDistance = (a, b) ->
		sum = 0
		for i in [0...Math.min a.length, b.length] by 1
			sum += Math.pow (a[i] - b[i]), 2
		Math.sqrt(sum)

	# These will be the 3 image datas that we track
	original = best = current = null
	stopped = false

	# The dimensions of the image we will learn
	width = height = 0

	# The canvas we will draw the current guess on
	canvas = $.synth("canvas.stop").prependTo("body")
	context = canvas.first().getContext('2d')
	context.clear = (c = 'black') ->
		@fillStyle = c
		@fillRect 0,0,width,height
	randomPoint = -> $ $.random.integer(0, width), $.random.integer(0,height)
	randomColor = -> "rgba(#{$.random.integer 0,256},#{$.random.integer 0,256},#{$.random.integer 0,256}, .5)"
	triangleCount = 0
	context.randomTriangle = ->
		triangleCount += 1
		offset = randomPoint().scale(.85)
		@beginPath()
		@moveTo (a = randomPoint().scale(.15).plus offset)...
		@lineTo randomPoint().scale(.15).plus(offset)...
		@lineTo randomPoint().scale(.15).plus(offset)...
		@lineTo a...
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
			video = $.synth("video[width=320][height=240]")
				.attr('src', URL.createObjectURL stream)
				.prependTo("body")
				.first()
			video.addEventListener 'loadedmetadata', (evt) ->
				$.log "on loadedmetadata", evt
				video.play()
				[width, height] = [320,240]
				canvas.attr { width, height }
				context = canvas.first().getContext('2d')
				$.delay 1000, ->
					$.log "Drawing to canvas", video
					video.pause()
					context.drawImage video, 0, 0, width, height
					cb null, video
					$("video").remove()
		onError = (err) -> cb err, null
		navigator.getUserMedia { video: true }, onVideo, onError

	# Set up the original from an image of the mona lisa
	setupImage = (cb) ->
		$.Promise.image("earring.jpg").wait (err, image) ->
			return cb(err, null) if err?
			$(image).attr({width:320,height:240}).prependTo("body")
			{width, height} = image
			canvas.attr { width, height }
			context.drawImage image, 0, 0, width, height
			cb null, image

	trianglesKept = 0
	runtime = 0
	last_frame = 0
	frame = ->
		return if stopped
		dt = $.now - last_frame
		runtime += dt
		last_frame += dt
		context.randomTriangle()
		$.delay 0, ->
			current = context.getImageData 0, 0, width, height
			current.dist = imageDistance current.data, original.data
			if current.dist < best.dist
				best = current
				window.setProgress best.dist, original.dist
				trianglesKept += 1
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
			else stageReady()

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
		pct = 100 * (max - cur) / max
		node = $("#progress")
		setGradient(node, pct)
		m = (trianglesKept / triangleCount).toFixed(4)
		if verbose
			node.text("Painting...")

