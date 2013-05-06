Object.keys or= (o) -> (k for k of o)
Object.values or= (o) -> (o[k] for k of o)
extend = (a, b...) ->
	for obj in b when obj
		a[k] = v for k,v of obj # when v?
	a
class Bling # extends (new Array)
	constructor: (args...) ->
		`return Bling.init(args)`
Bling.prototype = []
Bling.prototype.constructor = Bling
Bling.global = if window? then window else global
Bling.plugin = (opts, constructor) ->
	if not constructor
		constructor = opts
		opts = {}
	if "depends" of opts
		return @depends opts.depends, =>
			@plugin { provides: opts.provides }, constructor
	try
		if typeof (plugin = constructor?.call @,@) is "object"
			(Bling.plugin[opts.provides ? ""] or= []).push plugin
			extend @, plugin?.$
			delete plugin.$
			extend @prototype, plugin
			for key of plugin then do (key) =>
				@[key] or= (a...) => (@::[key].apply Bling(a[0]), a[1...])
			if opts.provides? then @provide opts.provides
	catch error
		console.log "failed to load plugin: #{@name} #{error.message}: #{error.stack}"
	@
extend Bling, do ->
	waiting = []
	complete = {}
	incomplete = (n) ->
		(if (typeof n) is "string" then n.split /, */ else n)
		.filter (x) -> not (x of complete)
	depends: depend = (needs, func) ->
		if (needs = incomplete needs).length is 0 then func()
		else
			waiting.push (need) ->
				(needs.splice i, 1) if (i = needs.indexOf need) > -1
				return (needs.length is 0 and func)
		func
	depend: depend # alias
	provide: (needs, data) ->
		for need in incomplete needs
			complete[need] = i = 0
			while i < waiting.length
				if (func = waiting[i] need)
					waiting.splice i,1
					func data
					i = 0 # start over in case a nested dependency removed stuff 'behind' i
				else i++
		data
$ = Bling
$.plugin
	depends: "core"
	provides: "async"
, ->
	return {
		series: (fin = $.identity) ->
			ret = $()
			todo = @length
			unless todo > 0
				fin.apply ret
				return @
			done = 0
			finish_one = (index) -> ->
				ret[index] = arguments
				if ++done >= todo
					fin.apply ret
				else next(done)
			do next = (i=0) => $.immediate => @[i](finish_one(i))
			return @
		parallel: (fin) ->
			ret = $()
			todo = @length
			unless todo > 0
				fin.apply ret
				return @
			done = 0
			finish_one = (index) -> ->
				ret[index] = arguments
				if ++done >= todo
					fin.apply ret
			for i in [0...todo] by 1
				@[i](finish_one(i))
	}
$.plugin
	provides: "cartesian"
, ->
	$:
		cartesian: (sets...) ->
			n = sets.length
			ret = []
			helper = (cur, i) ->
				(return ret.push cur) if ++i >= n
				for x in sets[i]
					helper (cur.concat x), i
				null
			helper [], -1
			return $(ret)
$.plugin ->
	String::trimLeft or= -> @replace(/^\s+/, "")
	String::split or= (sep) ->
		a = []; i = 0
		while (j = @indexOf sep,i) > -1
			a.push @substring(i,j)
			i = j + 1
		a
	String::lastIndexOf or= (s, c, i = -1) ->
		j = -1
		j = i while (i = s.indexOf c, i+1) > -1
		j
	Array::join or= (sep = '') ->
		n = @length
		return "" if n is 0
		s = @[n-1]
		while --n > 0
			s = @[n-1] + sep + s
		s
	if Event?
		Event::preventAll = () ->
			@preventDefault()
			@stopPropagation()
			@cancelBubble = true
	if Element?
		Element::matchesSelector = Element::webkitMatchesSelector or
			Element::mozMatchesSelector or
			Element::matchesSelector
		if Element::cloneNode.length is 0
			oldClone = Element::cloneNode
			Element::cloneNode = (deep = false) ->
				n = oldClone.call(@)
				if deep
					for i in @childNodes
						n.appendChild i.cloneNode true
				return n
	return { }
$.plugin
	provides: 'config'
	depends: 'type'
, ->
	get = (name, def) -> process.env[name] ? def
	set = (name, val) -> process.env[name] = val
	$: config: $.extend(get, {get: get, set: set})
$.plugin
	provides: "core"
	depends: "string"
, ->
	$.defineProperty $, "now",
		get: -> +new Date
	index = (i, o) ->
		i += o.length while i < 0
		Math.min i, o.length
	baseTime = $.now
	return {
		$:
			log: $.extend((a...) ->
				prefix = "+#{$.padLeft String($.now - baseTime), $.log.prefixSize, '0'}:"
				if prefix.length > $.log.prefixSize + 2
					prefix = "#{baseTime = $.now}:"
				if a.length and $.is "string", a[0]
					a[0] = "#{prefix} #{a[0]}"
				else
					a.unshift prefix
				console.log a...
				return a[a.length-1] if a.length
			, prefixSize: 5)
			assert: (c, m="") -> if not c then throw new Error("assertion failed: #{m}")
			coalesce: (a...) -> $(a).coalesce()
			keysOf: (o) -> $(k for k of o)
			valuesOf: (o) -> $.keysOf(o).map (k)->
				return try o[k] catch err then err
		eq: (i) -> $([@[index i, @]])
		each: (f) -> (f.call(t,t) for t in @); @
		map: (f) -> # CS comprehensions generate too much extra code for such a critical bottle-neck
			b = $()
			i = 0
			(b[i++] = f.call t,t) for t in @
			return b
		filterMap: (f) ->
			b = $()
			for t in @
				v = f.call t,t
				if v?
					b.push v
			b
		
		tap: (f) -> f.call @, @
		replaceWith: (array) ->
			for i in [0...array.length] by 1
				@[i] = array[i]
		reduce: (f, a) ->
			i = 0; n = @length
			a = @[i++] if not a?
			(a = f.call @[x], a, @[x]) for x in [i...n] by 1
			return a
		union: (other, strict = true) ->
			ret = $()
			ret.push(x) for x in @ when not ret.contains(x, strict)
			ret.push(x) for x in other when not ret.contains(x, strict)
			ret
		distinct: (strict = true) -> @union @, strict
		intersect: (other) -> $(x for x in @ when x in other) # another very beatiful expression
		contains: (item, strict = true) -> ((strict and t is item) or (not strict and `t == item`) for t in @).reduce ((a,x) -> a or x), false
		count: (item, strict = true) -> $(1 for t in @ when (item is undefined) or (strict and t is item) or (not strict and `t == item`)).sum()
		coalesce: ->
			for i in @
				if $.is('array',i) or $.is('bling',i) then i = $(i).coalesce()
				if i? then return i
			null
		swap: (i,j) ->
			i = index i, @
			j = index j, @
			if i isnt j
				[@[i],@[j]] = [@[j],@[i]]
			@
		shuffle: ->
			i = @length-1
			while i >= 0
				@swap --i, Math.floor(Math.random() * i)
			@
		select: do ->
			getter = (prop) -> -> if $.is("function",v = @[prop]) then $.bound(@,v) else v
			selectOne = (p) ->
				switch type = $.type p
					when 'regexp' then selectMany.call @, p
					when 'string'
						if (i = p.indexOf '.') > -1 then @select(p.substr 0,i).select(p.substr i+1)
						else @map(getter p)
					else $()
			selectMany = (a...) ->
				n = @length
				lists = Object.create(null)
				for p in a
					if $.is 'regexp', p
						for match in $.keysOf(@first()).filter(p)
							lists[match] = @select(match)
					else lists[p] = @select(p)
				i = 0
				@map ->
					obj = Object.create(null)
					for p of lists
						obj[$(p.split '.').last()] = lists[p][i]
					i++
					obj
			return ->
				switch arguments.length
					when 1 then selectOne.apply @, arguments
					when 2 then selectMany.apply @, arguments
		or: (x) -> @[i] or= x for i in [0...@length]; @
		zap: (p, v) ->
			if ($.is 'object', p) and not v?
				@zap(k,v) for k,v of p
				return @
			i = p.lastIndexOf "."
			if i > 0
				head = p.substr 0,i
				tail = p.substr i+1
				@select(head).zap tail, v
				return @
			switch $.type(v)
				when "array","bling" then @each -> @[p] = v[++i % v.length]
				when "function" then @zap p, @select(p).map(v)
				else @each -> @[p] = v
			@
		clean: (prop) -> @each -> delete @[prop]
		take: (n = 1) ->
			end = Math.min n, @length
			$( @[i] for i in [0...end] by 1 )
		skip: (n = 0) ->
			start = Math.max 0, n|0
			$( @[i] for i in [start...@length] by 1 )
		first: (n = 1) -> if n is 1 then @[0] else @take(n)
		last: (n = 1) -> if n is 1 then @[@length - 1] else @skip(@length - n)
		slice: (start=0, end=@length) ->
			start = index start, @
			end = index end, @
			$( @[i] for i in [start...end] )
		extend: (b) -> @.push(i) for i in b; @
		push: (b) -> Array::push.call(@, b); @
		filter: (f, limit=@length) ->
			g = switch $.type f
				when "string" then (x) -> x.matchesSelector(f)
				when "regexp" then (x) -> f.test(x)
				when "function" then f
				else throw new Error "unsupported argument to filter: #{$.type f}"
			a = $()
			for it in @
				if g.call(it,it)
					if --limit < 0
						break
					a.push it
			a
		matches: (expr) ->
			switch $.type expr
				when "string" then @select('matchesSelector').call(expr)
				when "regexp" then @map (x) -> expr.test x
				else throw new Error "unsupported argument to matches: #{$.type expr}"
		querySelectorAll: (expr) ->
			@filter("*")
			.reduce (a, i) ->
				a.extend i.querySelectorAll expr
			, $()
		weave: (b) ->
			c = $()
			for i in [@length-1..0] by -1
				c[(i*2)+1] = @[i]
			for i in [0...b.length] by 1
				c[i*2] = b[i]
			c
		fold: (f) ->
			n = @length
			b = $( f.call @, @[i], @[i+1] for i in [0...n-1] by 2 )
			if (n%2) is 1
				b.push( f.call @, @[n-1], undefined )
			b
		flatten: ->
			b = $()
			(b.push(j) for j in i) for i in @
			b
		call: -> @apply(null, arguments)
		apply: (context, args) ->
			@filterMap ->
				if $.is 'function', @ then @apply(context, args)
				else null
		log: (label) ->
			if label
				$.log(label, @toString(), @length + " items")
			else
				$.log(@toString(), @length + " items")
			@
		toArray: ->
			@__proto__ = Array::
			@ # no copies, yay?
		clear: -> @splice 0, @length
	}
$.plugin
	provides: 'date'
	depends: 'type'
, ->
	[ms,s,m,h,d] = [1,1000,1000*60,1000*60*60,1000*60*60*24]
	units = {
		ms, s, m, h, d,
		sec: s
		second: s
		seconds: s
		min: m
		minute: m
		minutes: m
		hr: h
		hour: h
		hours: h
		day: d
		days: d
	}
	formats =
		yyyy: Date::getUTCFullYear
		mm: -> @getUTCMonth() + 1
		dd: Date::getUTCDate
		HH: Date::getUTCHours
		MM: Date::getUTCMinutes
		SS: Date::getUTCSeconds
		MS: Date::getUTCMilliseconds
	format_keys = Object.keys(formats).sort().reverse()
	parsers =
		yyyy: Date::setUTCFullYear
		mm: (x) -> @setUTCMonth(x - 1)
		dd: Date::setUTCDate
		HH: Date::setUTCHours
		MM: Date::setUTCMinutes
		SS: Date::setUTCSeconds
		MS: Date::setUTCMilliseconds
	parser_keys = Object.keys(parsers).sort().reverse()
	floor = Math.floor
	$.type.register "date",
		match: (o) -> $.isType Date, o
		array: (o) -> [o]
		string: (o, fmt, unit) -> $.date.format o, fmt, unit
		number: (o, unit) -> $.date.stamp o, unit
	$.type.extend 'string', date: (o, fmt = $.date.defaultFormat) -> new Date $.date.parse o, fmt, "ms"
	$.type.extend 'number', date: (o, unit) -> $.date.unstamp o, unit
	adder = (key) ->
		(stamp, delta, stamp_unit = $.date.defaultUnit) ->
			date = $.date.unstamp(stamp, stamp_unit)
			parsers[key].call date, (formats[key].call date) + delta
			$.date.stamp date, stamp_unit
	$:
		date:
			defaultUnit: "s"
			defaultFormat: "yyyy-mm-dd HH:MM:SS"
			stamp: (date = new Date, unit = $.date.defaultUnit) ->
				floor (date / units[unit])
			unstamp: (stamp, unit = $.date.defaultUnit) ->
				new Date floor(stamp * units[unit])
			convert: (stamp, from = $.date.defaultUnit, to = $.date.defaultUnit) ->
				if $.is "date", stamp then stamp = $.date.stamp(stamp, from)
				(floor stamp * units[from] / units[to])
			midnight: (stamp, unit = $.date.defaultUnit) ->
				$.date.convert ($.date.convert stamp, unit, "d"), "d", unit
			format: (stamp, fmt = $.date.defaultFormat, unit = $.date.defaultUnit) ->
				if $.is "date", stamp then stamp = $.date.stamp(stamp, unit)
				date = $.date.unstamp stamp, unit
				for k in format_keys
					fmt = fmt.replace k, ($.padLeft ""+formats[k].call(date), k.length, "0")
				fmt
			parse: (dateString, fmt = $.date.defaultFormat, to = $.date.defaultUnit) ->
				date = new Date(0)
				for i in [0...fmt.length] by 1
					for k in parser_keys
						if fmt.indexOf(k, i) is i
							try
								parsers[k].call date,
									parseInt dateString[i...i+k.length], 10
							catch err
								throw new Error("Invalid date ('#{dateString}') given format mask: #{fmt} (failed at position #{i})")
				$.date.stamp date, to
			addMilliseconds: adder("MS")
			addSeconds: adder("SS")
			addMinutes: adder("MM")
			addHours: adder("HH")
			addDays: adder("dd")
			addMonths: adder("mm")
			addYears: adder("yyyy")
			range: (from, to, interval=1, interval_unit="dd", stamp_unit = $.date.defaultUnit) ->
				add = adder(interval_unit)
				ret = [from]
				while (cur = ret[ret.length-1]) < to
					ret.push add(cur, interval, stamp_unit)
				ret
	midnight: (unit = $.date.defaultUnit) -> @map(-> $.date.midnight @, unit)
	unstamp: (unit = $.date.defaultUnit) -> @map(-> $.date.unstamp @, unit)
	stamp: (unit = $.date.defaultUnit) -> @map(-> $.date.stamp @, unit)
	dateFormat: (fmt = $.date.defaultFormat, unit = $.date.defaultUnit) -> @map(-> $.date.format @, fmt, unit)
	dateParse: (fmt = $.date.defaultFormat, unit = $.date.defaultUnit) -> @map(-> $.date.parse @, fmt, unit)
$.plugin
	provides: "delay"
	depends: "function"
, ->
	$:
		delay: (->
			timeoutQueue = $.extend [], (->
				next = (a) -> -> a.shift()() if a.length
				add: (f, n) ->
					f.order = n + $.now
					for i in [0..@length] by 1
						if i is @length or @[i].order > f.order
							@splice i,0,f
							break
					setTimeout next(@), n
					@
				cancel: (f) ->
					for i in [0...@length] by 1
						if @[i] == f
							@splice i, 1
							break
					@
			)()
			(n, f) ->
				if $.is("function",f) then timeoutQueue.add(f, parseInt n)
				cancel: -> timeoutQueue.cancel(f)
		)()
		immediate: do ->
			return switch true
				when 'setImmediate' of $.global then $.global.setImmediate
				when process?.nextTick? then process.nextTick
				else (f) -> setTimeout(f, 0)
		interval: (n, f) ->
			$.delay n, g = -> f(); $.delay n, g
	delay: (n, f) ->
		$.delay n, f
		@
$.plugin
	depends: 'hook,synth,delay'
	provides: 'dialog'
, ->
	
	transition = (props, duration) ->
		props = props.split /, */
		["-webkit","-moz"].map((prefix) ->
			"#{prefix}-transition-property: #{props.join ', '}; #{prefix}-transition-duration: #{props.map(-> duration).join ", "};"
		).join ' '
	
	injectCSS = ->
		$('head style.dialog').remove()
		$.synth("style.dialog '
			.dialog, .modal { position: absolute; }
			.modal {
				background: rgba(0,0,0,.3);
				opacity: 0;
			}
			.dialog {
				box-shadow: 8px 8px 4px rgba(0,0,0,.4);
				border-radius: 8px;
				background: white;
				padding: 6px; #{transition "left", ".15s"}
			}
			.dialog > .title {
				text-align: center;
				width: 100%;
			}
			.dialog > .content {
				width: 100%;
			}
		'".replace(/\t+|\n+/g,' ')).prependTo("head")
	createDialog = (opts) ->
		opts = $.extend createDialog.getDefaultOptions(), opts
		injectCSS()
		dialogSynth = ""
		modal = $.synth("div.modal div.dialog##{opts.id} div.title + div.content")
			.appendTo("body")
			.click (evt) ->
				if evt.target is modal[0]
					$.log 'dialog: Cancelling because the modal was clicked.'
					opts.cancel(modal)
		dialog = modal.find('.dialog', 1)
		modal
			.delegate(".cancel", "click", (evt) -> opts.cancel(modal))
			.delegate(".ok", "click", (evt) -> opts.ok(modal))
		contentNode = dialog.find('.content', 1)
		contentNode.append createDialog.getContent opts.contentType, opts.content
		titleNode = dialog.find('.title', 1)
		titleNode.append createDialog.getContent opts.titleType, opts.title
		$(opts.target).bind('resize', (evt) ->
			modal.fitOver(opts.target).fadeIn(200)
			dialog.centerOn(modal).show()
		).trigger('resize')
		dialog
	
	createDialog.getDefaultOptions = ->
		id: "dialog-" + $.random.string 4
		target: "body"
		title: "Untitled Dialog"
		titleType: "text"
		content: "span 'Dialog Content'"
		contentType: "synth"
		ok: (modal) ->
			$.log "dialog: Closing from default ok"
			modal.emit('ok')
				.fadeOut(200, -> modal.remove())
		cancel: (modal) ->
			$.log "dialog: Closing from default cancel"
			modal.emit('cancel')
				.fadeOut(200, -> modal.remove())
				.find(".dialog", 1).css left: 0
	
	createDialog.getContent = (type, stuff) ->
		switch type
			when "synth" then $.synth(stuff)
			when "html" then $.HTML.parse(stuff)
			when "text" then document.createTextNode(stuff)
	
	return {
		$:
			dialog: createDialog
		fitOver: (elem = window) ->
			if elem is window
				rect =
					width: window.innerWidth
					height: window.innerHeight
					top: 0
					left: 0
			else
				rect = $(elem).rect().first()
			@css
				position: 'absolute'
				width: $.px rect.width
				height: $.px rect.height
				top: $.px rect.top
				left: $.px rect.left
		centerOn: (elem = window) ->
			if elem is window
				target =
					width: window.innerWidth
					height: window.innerHeight
					top: 0
					left: 0
			else
				target = $(elem).rect().first()
			top = target.height / 2
			left = target.width / 2
			@each ->
				dialog = $ @
				rect = dialog.rect().first()
				dialog.css
					top: $.px top - (rect.height / 2)
					left: $.px left - (rect.width / 2)
	}
$.plugin
	depends: "core"
	provides: "diff"
, ->
	lev_memo = Object.create null
	lev = (s,i,n,t,j,m,dw,iw,sw) ->
		return lev_memo[[s,i,n,t,j,m,dw,iw,sw]] ?= lev_memo[[t,j,m,s,i,n,dw,iw,sw]] ?= do -> switch true
			when m <= 0 then n
			when n <= 0 then m
			else Math.min(
				dw + lev(s,i+1,n-1, t,j,m,dw,iw,sw),
				iw + lev(s,i,n, t,j+1,m-1,dw,iw,sw),
				(sw * (s[i] isnt t[j])) + lev(s,i+1,n-1, t,j+1,m-1,dw,iw,sw)
			)
	
	collapse = (ops) -> # combines similar operations in a sequence
		$.inherit {
			toHTML: ->
				@reduce(((a,x) ->
					a += switch x.op
						when 'ins' then "<ins>#{x.v}</ins>"
						when 'del' then "<del>#{x.v}</del>"
						when 'sub' then "<del>#{x.v}</del><ins>#{x.w}</ins>"
						when 'sav' then x.v
				), "")
		}, ops.reduce(((a,x) ->
			if x.op is 'sub' and x.v is x.w # replacing with the same thing is just preserving
				x.op = 'sav'
				delete x.w
			unless a.length
				a.push x
			else
				if (last = a.last()).op is x.op
					last.v += x.v
					if last.op is 'sub'
						last.w += x.w
				else
					a.push x
			return a
		), $())
	diff_memo = Object.create null
	del = (c) -> {op:'del',v:c}
	ins = (c) -> {op:'ins',v:c}
	sub = (c,d) -> {op:'sub',v:c,w:d}
	diff = (s,i,n,t,j,m,dw,iw,sw) ->
		return diff_memo[[s,i,n,t,j,m,dw,iw,sw]] ?= collapse do -> switch true
			when m <= 0 then (del c) for c in s.substr i,n
			when n <= 0 then (ins c) for c in t.substr j,m
			else
				sw *= (s[i] isnt t[j])
				args =
					del: [s,i+1,n-1, t,j,m,     1,1.5,1.5]
					ins: [s,i,n, t,j+1,m-1,     1.5,1,1.5]
					sub: [s,i+1,n-1, t,j+1,m-1, 1,1,1]
				costs =
					del: dw + lev args.del...
					ins: iw + lev args.ins...
					sub: sw + lev args.sub...
				switch Math.min costs.del, costs.ins, costs.sub
					when costs.del then $(del s[i]).concat diff args.del...
					when costs.ins then $(ins t[j]).concat diff args.ins...
					when costs.sub then $(sub s[i],t[j]).concat diff args.sub...
	$:
		stringDistance: (s, t) -> lev s,0,s.length, t,0,t.length,1,1,1
		stringDiff: (s, t) -> diff s,0,s.length, t,0,t.length,1,1,1.5
if $.global.document?
	$.plugin
		depends: "function,type"
		provides: "dom"
	, ->
		bNodelistsAreSpecial = false
		$.type.register "nodelist",
			match:  (o) -> o? and $.isType "NodeList", o
			hash:   (o) -> $($.hash(i) for i in x).sum()
			array:  do ->
				try # probe to see if this browsers allows direct modification of a nodelist's prototype
					document.querySelectorAll("xxx").__proto__ = {}
					return $.identity
				catch err # if we can't patch directly, we have to copy into a real array :(
					bNodelistsAreSpecial = true
					return (o) -> (node for node in o)
			string: (o) -> "{Nodelist:["+$(o).select('nodeName').join(",")+"]}"
			node:   (o) -> $(o).toFragment()
		$.type.register "node",
			match:  (o) -> o?.nodeType > 0
			hash:   (o) -> $.checksum(o.nodeName) + $.hash(o.attributes) + $.checksum(o.innerHTML)
			string: (o) -> o.toString()
			node:   $.identity
		$.type.register "fragment",
			match:  (o) -> o?.nodeType is 11
			hash:   (o) -> $($.hash(x) for x in o.childNodes).sum()
			string: (o) -> o.toString()
			node:   $.identity
		$.type.register "html",
			match:  (o) -> typeof o is "string" and (s=o.trimLeft())[0] == "<" and s[s.length-1] == ">"
			node:   (h) ->
				(node = document.createElement('div')).innerHTML = h
				if (n = (childNodes = node.childNodes).length) is 1
					return node.removeChild(childNodes[0])
				df = document.createDocumentFragment()
				df.appendChild(node.removeChild(childNodes[0])) for i in [0...n] by 1
				df
			array:  (o) -> $.type.lookup(h = Bling.HTML.parse o).array h
			string: (o) -> "'#{o}'"
			repr:   (o) -> '"' + o + '"'
		$.type.extend
			unknown:  { node: -> null }
			bling:    { node: (o) -> o.toFragment() }
			node:     { html: (n) ->
				d = document.createElement "div"
				d.appendChild (n = n.cloneNode true)
				ret = d.innerHTML
				d.removeChild n # break links to prevent leaks
				ret
			}
			string:
				node:  (o) -> $(o).toFragment()
				array: do ->
					if bNodelistsAreSpecial
						(o) -> $.type.lookup(nl = document.querySelectorAll o).array(nl)
					else
						(o) -> document.querySelectorAll o
			function: { node: (o) -> $(o.toString()).toFragment() }
		toFrag = (a) ->
			if not a.parentNode?
				df = document.createDocumentFragment()
				df.appendChild a
			a
		before = (a,b) -> toFrag(a).parentNode.insertBefore b, a
		after = (a,b) -> toFrag(a).parentNode.insertBefore b, a.nextSibling
		toNode = (x) -> $.type.lookup(x).node x
		escaper = false
		parser = false
		$.computeCSSProperty = computeCSSProperty = (k) -> -> $.global.getComputedStyle(@, null).getPropertyValue k
		getOrSetRect = (p) -> (x) -> if x? then @css(p, x) else @rect().select p
		selectChain = (prop) -> -> @map (p) -> $( p while p = p[prop] )
		return {
			$:
				HTML:
					parse: (h) -> $.type.lookup(h).node h
					stringify: (n) -> $.type.lookup(n).html n
					escape: (h) ->
						escaper or= $("<div>&nbsp;</div>").child 0
						ret = escaper.zap('data', h).select("parentNode.innerHTML").first()
						escaper.zap('data', '')
						ret
			html: (h) ->
				return switch $.type h
					when "undefined","null" then @select 'innerHTML'
					when "string","html" then @zap 'innerHTML', h
					when "bling" then @html h.toFragment()
					when "node"
						@each -> # replace all our children with the new child
							@replaceChild @childNodes[0], h
							while @childNodes.length > 1
								@removeChild @childNodes[1]
			append: (x) -> # .append(/n/) - insert /n/ [or a clone] as the last child of each node
				x = toNode(x) # parse, cast, do whatever it takes to get a Node or Fragment
				@each -> @appendChild x.cloneNode true
			appendText: (text) ->
				node = document.createTextNode(text)
				@each -> @appendChild node.cloneNode true
			appendTo: (x) -> # .appendTo(/n/) - each node [or fragment] will become the last child of x
				clones = @map( -> @cloneNode true)
				i = 0
				$(x).each -> @appendChild clones[i++]
				clones
			prepend: (x) -> # .prepend(/n/) - insert n [or a clone] as the first child of each node
				if x?
					x = toNode x
					@take(1).each ->
						before @childNodes[0], x
					@skip(1).each ->
						before @childNodes[0], x.cloneNode true
				@
			prependTo: (x) -> # .prependTo(/n/) - each node [or a fragment] will become the first child of x
				if x?
					$(x).prepend(@)
				@
			before: (x) -> # .before(/x/) - insert content x before each node
				if x?
					x = toNode x
					@take(1).each -> before @, x
					@skip(1).each -> before @, x.cloneNode true
				@
			after: (x) -> # .after(/n/) - insert content n after each node
				if x?
					x = toNode x
					@take(1).each -> after @, x
					@skip(1).each -> after @, x.cloneNode true
				@
			wrap: (parent) -> # .wrap(/parent/) - parent becomes the new .parentNode of each node
				parent = toNode parent
				if $.is "fragment", parent
					throw new Error("cannot call .wrap() with a fragment as the parent")
				@each (child) ->
					if ($.is "fragment", child) or not child.parentNode
						return parent.appendChild child
					grandpa = child.parentNode
					marker = document.createElement "dummy"
					parent.appendChild grandpa.replaceChild marker, child
					grandpa.replaceChild parent, marker
			unwrap: -> # .unwrap() - replace each node's parent with itself
				@each ->
					if @parentNode and @parentNode.parentNode
						@parentNode.parentNode.replaceChild(@, @parentNode)
					else if @parentNode
						@parentNode.removeChild(@)
			replace: (n) -> # .replace(/n/) - replace each node with n [or a clone]
				n = toNode n
				clones = @map(-> n.cloneNode true)
				for i in [0...clones.length] by 1
					@[i].parentNode?.replaceChild clones[i], @[i]
				clones
			attr: (a,v) -> # .attr(a, [v]) - get [or set] an /a/ttribute [/v/alue]
				if $.is 'object', a
					@attr(k,v) for k,v of a
				else switch v
					when undefined
						return @select("getAttribute").call(a, v)
					when null
						@select("removeAttribute").call(a, v); @
					else
						@select("setAttribute").call(a, v)
				@
			data: (k, v) -> @attr "data-#{$.dashize(k)}", v
			addClass: (x) -> # .addClass(/x/) - add x to each node's .className
				notempty = (y) -> y isnt ""
				@removeClass(x).each ->
					c = @className.split(" ").filter notempty
					c.push x
					@className = c.join " "
			removeClass: (x) -> # .removeClass(/x/) - remove class x from each node's .className
				notx = (y) -> y != x
				@each ->
					c = @className.split(" ").filter(notx).join(" ")
					if c.length is 0
						@removeAttribute('class')
			toggleClass: (x) -> # .toggleClass(/x/) - add, or remove if present, class x from each node
				notx = (y) -> y isnt x
				@each ->
					cls = @className.split(" ")
					filter = $.not $.isEmpty
					if( cls.indexOf(x) > -1 )
						filter = $.and notx, filter
					else
						cls.push x
					c = cls.filter(filter).join(" ")
					@className = c
					if c.length is 0
						@removeAttribute('class')
			hasClass: (x) -> # .hasClass(/x/) - true/false for each node: whether .className contains x
				@select('className.split').call(" ").select('indexOf').call(x).map (x) -> x > -1
			text: (t) -> # .text([t]) - get [or set] each node's .textContent
				return @zap('textContent', t) if t?
				return @select('textContent')
			val: (v) -> # .val([v]) - get [or set] each node's .value
				return @zap('value', v) if v?
				return @select('value')
			css: (key,v) ->
				if v? or $.is('object', key)
					setters = @select 'style.setProperty'
					if $.is "object", key then setters.call k, v, "" for k,v of key
					else if $.is "array", v
						for i in [0...n = Math.max v.length, nn = setters.length] by 1
							setters[i%nn](key, v[i%n], "")
					else if $.is 'function', v
						values = @select("style.#{key}")
							.weave(@map computeCSSProperty key)
							.fold($.coalesce)
							.weave(setters)
							.fold (setter, value) -> setter(key, v.call value, value)
					else setters.call key, v, ""
					return @
				else @select("style.#{key}")
					.weave(@map computeCSSProperty key)
					.fold($.coalesce)
			defaultCss: (k, v) ->
				sel = @selector
				style = ""
				if $.is "string", k
					if $.is "string", v
						style += "#{sel} { #{k}: #{v} } "
					else throw Error("defaultCss requires a value with a string key")
				else if $.is "object", k
					style += "#{sel} { " +
						"#{i}: #{k[i]}; " for i of k +
					"} "
				$("<style></style>").text(style).appendTo("head")
				@
			rect: -> @map (item) -> switch item
				when window then {
					width: window.innerWidth
					height: window.innerHeight
					top: 0
					left: 0
					right: window.innerWidth
					bottom: window.innerHeight
				}
				else item.getBoundingClientRect()
			width: getOrSetRect("width")
			height: getOrSetRect("height")
			top: getOrSetRect("top")
			left: getOrSetRect("left")
			bottom: getOrSetRect("bottom")
			right: getOrSetRect("right")
			position: (left, top) ->
				switch true
					when not left? then @rect()
					when not top? then @css("left", $.px(left))
					else @css({top: $.px(top), left: $.px(left)})
			scrollToCenter: ->
				document.body.scrollTop = @[0].offsetTop - ($.global.innerHeight / 2)
				@
			child: (n) -> @select('childNodes').map -> @[ if n < 0 then (n+@length) else n ]
			parents: selectChain('parentNode')
			prev: selectChain('previousSibling')
			next: selectChain('nextSibling')
			remove: -> @each -> @parentNode?.removeChild(@)
			find: (css, limit = 0) ->
				@filter("*")
					.map(
						switch limit
							when 0 then (-> @querySelectorAll css)
							when 1 then (-> $ @querySelector css)
							else (-> $(@querySelectorAll css).take(limit) )
					)
					.flatten()
			clone: (deep=true) -> @map -> (@cloneNode deep) if $.is "node", @
			toFragment: ->
				if @length > 1
					df = document.createDocumentFragment()
					(@map toNode).map (node) -> df.appendChild(node)
					return df
				return toNode @[0]
		}
$.plugin
	provides: "EventEmitter"
	depends: "type,hook"
, ->
	$: EventEmitter: Bling.init.append (obj = {}) ->
		listeners = Object.create null
		list = (e) -> (listeners[e] or= [])
		$.inherit {
			emit:               (e, a...) -> (f.apply(@, a) for f in list(e)); @
			on: add = (e, f) ->
				switch $.type e
					when 'object' then @addListener(k,v) for k,v of e
					when 'string'
						list(e).push(f)
						@emit('newListener', e, f)
				return @
			addListener: add
			removeListener:     (e, f) -> (l.splice i, 1) if (i = (l = list e).indexOf f) > -1
			removeAllListeners: (e) -> listeners[e] = []
			setMaxListeners:    (n) -> # who really needs this in the core API?
			listeners:          (e) -> list(e).slice 0
		}, obj
$.plugin
	depends: "dom,function,core"
	provides: "event"
, ->
	EVENTSEP_RE = /,* +/
	events = ['mousemove','mousedown','mouseup','mouseover','mouseout','blur','focus',
		'load','unload','reset','submit','keyup','keydown','change',
		'abort','cut','copy','paste','selection','drag','drop','orientationchange',
		'touchstart','touchmove','touchend','touchcancel',
		'gesturestart','gestureend','gesturecancel',
		'hashchange'
	]
	binder = (e) ->
		(f) ->
			if ($.is "function", f) then @bind(e, f)
			else @trigger(e, f)
	register_live = (selector, context, evt, f, h) ->
		$(context).bind(evt, h)
			.each -> (((@__alive__ or= {})[selector] or= {})[evt] or= {})[f] = h
	unregister_live = (selector, context, e, f) ->
		$c = $(context)
		$c.each ->
			a = (@__alive__ or= {})
			b = (a[selector] or= {})
			c = (b[e] or= {})
			$c.unbind(e, c[f])
			delete c[f]
	triggerReady = $.once ->
		$(document).trigger("ready").unbind("ready")
		document.removeEventListener?("DOMContentLoaded", triggerReady, false)
		$.global.removeEventListener?("load", triggerReady, false)
	bindReady = $.once ->
		document.addEventListener?("DOMContentLoaded", triggerReady, false)
		$.global.addEventListener?("load", triggerReady, false)
	bindReady()
	ret = {
		bind: (e, f) ->
			c = (e or "").split(EVENTSEP_RE)
			h = (evt) ->
				ret = f.apply @, arguments
				if ret is false
					evt.preventAll()
				ret
			@each ->
				(@addEventListener i, h, false) for i in c
		unbind: (e, f) ->
			c = (e or "").split EVENTSEP_RE
			@each -> (@removeEventListener i, f, null) for i in c
		trigger: (evt, args = {}) ->
			args = $.extend
				bubbles: true
				cancelable: true
			, args
			for evt_i in (evt or "").split(EVENTSEP_RE)
				if evt_i in ["click", "mousemove", "mousedown", "mouseup", "mouseover", "mouseout"] # mouse events
					e = document.createEvent "MouseEvents"
					args = $.extend
						detail: 1,
						screenX: 0,
						screenY: 0,
						clientX: 0,
						clientY: 0,
						ctrlKey: false,
						altKey: false,
						shiftKey: false,
						metaKey: false,
						button: 0,
						relatedTarget: null
					, args
					e.initMouseEvent evt_i, args.bubbles, args.cancelable, $.global, args.detail, args.screenX, args.screenY,
						args.clientX, args.clientY, args.ctrlKey, args.altKey, args.shiftKey, args.metaKey,
						args.button, args.relatedTarget
				else if evt_i in ["blur", "focus", "reset", "submit", "abort", "change", "load", "unload"] # UI events
					e = document.createEvent "UIEvents"
					e.initUIEvent evt_i, args.bubbles, args.cancelable, $.global, 1
				else if evt_i in ["touchstart", "touchmove", "touchend", "touchcancel"] # touch events
					e = document.createEvent "TouchEvents"
					args = $.extend
						detail: 1,
						screenX: 0,
						screenY: 0,
						clientX: 0,
						clientY: 0,
						ctrlKey: false,
						altKey: false,
						shiftKey: false,
						metaKey: false,
						touches: [],
						targetTouches: [],
						changedTouches: [],
						scale: 1.0,
						rotation: 0.0
					, args
					e.initTouchEvent(evt_i, args.bubbles, args.cancelable, $.global, args.detail, args.screenX, args.screenY,
						args.clientX, args.clientY, args.ctrlKey, args.altKey, args.shiftKey, args.metaKey,
						args.touches, args.targetTouches, args.changedTouches, args.scale, args.rotation)
				else if evt_i in ["gesturestart", "gestureend", "gesturecancel"] # gesture events
					e = document.createEvent "GestureEvents"
					args = $.extend {
						detail: 1,
						screenX: 0,
						screenY: 0,
						clientX: 0,
						clientY: 0,
						ctrlKey: false,
						altKey: false,
						shiftKey: false,
						metaKey: false,
						target: null,
						scale: 1.0,
						rotation: 0.0
					}, args
					e.initGestureEvent evt_i, args.bubbles, args.cancelable, $.global, args.detail, args.screenX, args.screenY,
						args.clientX, args.clientY, args.ctrlKey, args.altKey, args.shiftKey, args.metaKey,
						args.target, args.scale, args.rotation
				else
					e = document.createEvent "Events"
					e.initEvent evt_i, args.bubbles, args.cancelable
					try
						e = $.extend e, args
					catch err
						$.log "Error in dispatch: ", err
				if not e
					continue
				else
					try
						@each ->
							@dispatchEvent e
					catch err
						$.log "dispatchEvent error:", err
			@
		delegate: (selector, e, f) ->
			context = @
			register_live selector, context, e, f, (evt) ->
				context.find(selector)
					.intersect($(evt.target).parents().first().union($(evt.target)))
					.each -> f.call(evt.target = @, evt)
		undelegate: (selector, e, f) ->
			@unbind e, unregister_live selector, @, e, f
		click: (f = {}) ->
			if @css("cursor") in ["auto",""]
				@css "cursor", "pointer"
			if $.is "function", f then @bind 'click', f
			else @trigger 'click', f
			@
		ready: (f) ->
			return (f.call @) if triggerReady.exhausted
			@bind "ready", f
	}
	events.forEach (x) -> ret[x] = binder(x)
	return ret
$.plugin
	provides: "function"
	depends: "hash"
, ->
	$:
		identity: (o) -> o
		not: (f) -> -> not f.apply @, arguments
		compose: (f,g) -> (x) -> f.call(y, (y = g.call(x,x)))
		and: (f,g) -> (x) -> g.call(@,x) and f.call(@,x)
		once: (f, n=1) ->
			$.defineProperty (-> (f.apply @,arguments) if n-- > 0),
				"exhausted",
					get: -> n <= 0
		cycle: (f...) ->
			i = -1
			-> f[i = ++i % f.length].apply @, arguments
		bound: (t, f, args = []) ->
			return $.identity unless f?
			if $.is "function", f.bind
				args.splice 0, 0, t
				r = f.bind.apply f, args
			else
				r = (a...) -> f.apply t, (args if args.length else a)
			$.extend r, { toString: -> "bound-method of #{t}.#{f.name}" }
		partial: (f, a...) -> (b...) -> f a..., b...
	partial: (a...) -> @map (f) -> $.partial f, a...
$.plugin
	provides: "groupBy"
, ->
	groupBy: (key) ->
		groups = {}
		switch $.type key
			when 'array','bling'
				@each ->
					c = (@[k] for k in key).join ","
					(groups[c] or= $()).push @
			else @each -> (groups[@[key]] or= $()).push @
		return $.valuesOf groups
$.plugin
	provides: "hash"
	depends: "type"
, ->
	maxHash = Math.pow(2,32)
	$.type.extend
		unknown: { hash: (o) -> $.checksum $.toString o }
		object:  { hash: (o) ->
			$.hash(Object) +
				$($.hash(k) + $.hash(v) for k,v of o).sum()
		}
		array:   { hash: (o) ->
			$.hash(Array) + $(o.map $.hash).reduce(((a,x) -> ((a*a)+(x|0)) % maxHash), 1)
		}
		bool:    { hash: (o) -> parseInt(1 if o) }
	return {
		$:
			hash: (x) -> $.type.lookup(x).hash(x)
		hash: -> $.hash @
	}
$.plugin ->
	$:
		histogram: (data, bucket_width=1, output_width=60) ->
			buckets = $()
			len = 0
			min = Infinity
			mean = 0
			max = 0
			total = 0
			for x in data
				min = Math.min x, min
				max = Math.max x, max
				total += x
				i = Math.floor( x / bucket_width )
				if i of buckets
					buckets[i] += 1
				else
					buckets[i] = 1
				len = Math.max(len, i+1)
			buckets.length = len
			mean = total / data.length
			m = buckets.max()
			buckets = buckets.or(0)
				.scale(1/m)
				.scale(output_width)
			sum = buckets.sum()
			ret = ""
			pct_sum = 0
			for n in [0...len] by 1
				end = (n+1) * bucket_width
				pct = (buckets[n]*100/sum)
				pct_sum += pct
				ret += $.padLeft(pct_sum.toFixed(2)+"%",7) +
					$.padRight(" < #{end.toFixed(2)}", 10) +
					": " + $.repeat("#", buckets[n]) + "\n"
			ret + "N: #{data.length} Min: #{min.toFixed(2)} Max: #{max.toFixed(2)} Mean: #{mean.toFixed(2)}"
	histogram: -> $.histogram @
$.plugin
	provides: "hook"
	depends: "type"
, ->
	hook = ->
		chain = []
		return $.extend ((args) ->
			for func in chain
				args = func.call @, args
			args
		), {
			prepend: (obj) -> chain.unshift(obj); obj
			append: (obj) -> chain.push(obj); obj
		}
	Bling.init = hook()
	Bling.init.prepend (args) ->
		if args.length is 1
			args = $.type.lookup(args[0]).array(args[0])
		b = $.inherit Bling, args
		if args.length is 0 and args[0] isnt undefined
			i = 0
			i++ while args[i] isnt undefined
			b.length = i
		b
	$: hook: hook
$.plugin
	depends: "dom"
	provides: "http"
, ->
	formencode = (obj) -> # create &foo=bar strings from object properties
		o = JSON.parse(JSON.stringify(obj)) # quickly remove all non-stringable items
		("#{i}=#{escape o[i]}" for i of o).join "&"
	$.type.register "http",
		match: (o) -> $.isType 'XMLHttpRequest', o
		array: (o) -> [o]
	return {
		$:
			http: (url, opts = {}) ->
				xhr = new XMLHttpRequest()
				if $.is "function", opts
					opts = success: $.bound(xhr, opts)
				opts = $.extend {
					method: "GET"
					data: null
					state: $.identity # onreadystatechange
					success: $.identity # onload
					error: $.identity # onerror
					async: true
					asBlob: false
					timeout: 0 # milliseconds, 0 is forever
					followRedirects: false
					withCredentials: false
				}, opts
				opts.state = $.bound(xhr, opts.state)
				opts.success = $.bound(xhr, opts.success)
				opts.error = $.bound(xhr, opts.error)
				if opts.data and opts.method is "GET"
					url += "?" + formencode(opts.data)
				else if opts.data and opts.method is "POST"
					opts.data = formencode(opts.data)
				xhr.open(opts.method, url, opts.async)
				xhr = $.extend xhr,
					asBlob: opts.asBlob
					timeout: opts.timeout
					followRedirects: opts.followRedirects
					withCredentials: opts.withCredentials
					onreadystatechange: ->
						opts.state?()
						if xhr.readyState is 4
							if xhr.status is 200
								opts.success xhr.responseText
							else
								opts.error xhr.status, xhr.statusText
				xhr.send opts.data
				return $(xhr)
			post: (url, opts = {}) ->
				if $.is("function",opts)
					opts = success: opts
				opts.method = "POST"
				$.http(url, opts)
			get: (url, opts = {}) ->
				if( $.is("function",opts) )
					opts = success: opts
				opts.method = "GET"
				$.http(url, opts)
	}
$.depends 'hook', ->
	Bling.init.append (obj) ->
		map = Object.create(null)
		keyMakers = []
		$.inherit {
			index: (keyFunc) ->
				if keyMakers.indexOf(keyFunc) is -1
					keyMakers.push keyFunc
					map[keyFunc] = Object.create(null)
				@each (x) ->
					map[keyFunc][keyFunc(x)] = x
			query: (criteria) ->
				for keyMaker in keyMakers
					key = keyMaker(criteria)
					return map[keyMaker][key] if key of map[keyMaker]
				null
		}, obj
$.plugin
	depends: "dom"
	provides: "lazy"
, ->
	lazy_load = (elementName, props) ->
		$("head").append $.extend document.createElement(elementName), props
	$:
		script: (src) ->
			lazy_load "script", { src: src }
		style: (src) ->
			lazy_load "link", { href: src, rel: "stylesheet" }
$.plugin
	provides: "math"
	depends: "core"
, ->
	$.type.extend
		bool: { number: (o) -> if o then 1 else 0 }
		number: { bool: (o) -> not not o }
	_By = (cmp) ->
		(field) ->
			valueOf = switch $.type field
				when "string" then (o) -> o[field]
				when "function" then field
				else throw new Error ".maxBy first argument should be a string or function"
			x = @first()
			@skip(1).each ->
				if cmp valueOf(@), valueOf(x)
					x = @
			return x
	$:
		range: (start, end, step = 1) ->
			if not end? then (end = start; start = 0)
			step *= -1 if end < start and step > 0 # force step to have the same sign as start->end
			$( (start + (i*step)) for i in [0...Math.ceil( (end - start) / step )] )
		zeros: (n) -> $( 0 for i in [0...n] )
		ones: (n) -> $( 1 for i in [0...n] )
		deg2rad: (n) -> n * Math.PI / 180
		rad2deg: (n) -> n * 180 / Math.PI
	floats: -> @map parseFloat
	ints: -> @map -> parseInt @, 10
	px: (delta) -> @ints().map -> $.px @,delta
	min: -> @filter( isFinite ).reduce Math.min
	max: -> @filter( isFinite ).reduce Math.max
	maxBy: _By (a,b) -> a > b
	minBy: _By (a,b) -> a < b
	mean: mean = -> if not @length then 0 else @sum() / @length
	avg: mean
	sum: -> @filter( isFinite ).reduce(((a) -> a + @), 0)
	product: -> @filter( isFinite ).reduce (a) -> a * @
	squares: -> @pow(2)
	pow: (n) -> @map -> Math.pow @, n
	magnitude: -> Math.sqrt @floats().squares().sum()
	scale: (r) -> @map -> r * @
	add: add = (d) -> switch $.type(d)
		when "number" then @map -> d + @
		when "bling","array" then $( @[i]+d[i] for i in [0...Math.min(@length,d.length)] )
	plus: add
	sub: sub = (d) -> switch $.type d
		when "number" then @map -> @ - d
		when "bling","array" then $( @[i]-d[i] for i in [0...Math.min @length, d.length])
	minus: sub
	dot: (b) ->
		$.sum( @[i]*b[i] for i in [0...Math.min(@length,b.length)] )
	angle: (b) -> Math.acos (@dot(b) / (@magnitude() * b.magnitude()))
	cross: (b) ->
		$ @[1]*b[2] - @[2]*b[1],
			@[2]*b[0] - @[0]*b[2],
			@[0]*b[1] - @[1]*b[0]
	normalize: -> @scale 1 / @magnitude()
	deg2rad: -> @filter( isFinite ).map -> @ * Math.PI / 180
	rad2deg: -> @filter( isFinite ).map -> @ * 180 / Math.PI
$.plugin
	depends: 'function'
	provides: 'memoize'
, ->
	$:
		memoize: (opts) ->
			if $.is 'function', opts
				opts = f: opts
			if not $.is 'object', opts
				throw new Error "Argument Error: memoize requires either a function or object as first argument"
			opts.cache or= Object.create(null)
			opts.hash or= $.identity
			return ->
				opts.cache[opts.hash(arguments)] ?= opts.f.apply @, arguments
	
$.plugin
	depends: "core,function"
	provides: "promise"
, ->
	NoValue = -> # a totem
	Promise = (obj = {}) ->
		waiting = $()
		err = result = NoValue
		return $.inherit {
			wait: (cb) ->
				return cb(err,null) if err isnt NoValue
				return cb(null,result) if result isnt NoValue
				waiting.push cb
				@
			finish: (value) ->
				waiting.call null, result = value
				waiting.clear()
				@
			fail: (error)  ->
				waiting.call err = error, null
				waiting.clear()
				@
			reset: ->
				err = result = NoValue
				@
		}, $.EventEmitter(obj)
	Progress = (max = 1.0) ->
		cur = 0.0
		progress = (args...) ->
		return $.inherit {
			progress: (args...) ->
				return cur unless args.length
				cur = args[0]
				if args.length > 1
					max = args[1]
				@finish(cur) if cur >= max
				@emit 'progress', cur, max
				@
			progressInc: (delta = 1) -> @progress cur + delta
			progressMax: (q) -> max = q
		}, Promise()
	Promise.xhr = (xhr) ->
		p = $.Promise()
		xhr.onreadystatechange = ->
			if @readyState is @DONE
				if @status is 200
					p.finish xhr.responseText
				else
					p.fail "#{@status} #{@statusText}"
		return p
	$.depend 'dom', ->
		Promise.image = (src) ->
			p = $.Promise()
			image = new Image()
			image.onload = -> p.finish(image)
			image.onerror = (evt) -> p.fail(evt)
			image.src = src
			return p
	ret = { $: { Promise, Progress } }
$.plugin
	depends: "core"
	provides: "pubsub"
, ->
	class Hub
		constructor: ->
			@listeners = {} # a mapping of channel name to a list of listeners
		publish: (channel, args...) ->
			f.apply null, args for f in (@listeners[channel] or= [])
			args
		publisher: (channel, func) -> # Use as a function decorator
			t = @
			-> t.publish channel, func.apply @, arguments
		subscribe: (channel, func) ->
			(@listeners[channel] or= []).push func
			func
		unsubscribe: (channel, func) ->
			if not func?
				@listeners[channel] = []
			else
				a = (@listeners[channel] or= [])
				if (i = a.indexOf func)  > -1
					a.splice(i,i)
	return {
		$: $.extend new Hub(),
			Hub: Hub
	}
$.plugin
	provides: 'random'
	depends: 'type'
, ->
	alphabet = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ".split ""
	$: random: do -> # Mersenne Twister algorithm, from the psuedocode on wikipedia
		MT = new Array(624)
		index = 0
		init_generator = (seed) ->
			index = 0
			MT[0] = seed
			for i in [1..623]
				MT[i] = 0xFFFFFFFF & (1812433253 * (MT[i-1] ^ (MT[i-1] >>> 30)) + i)
		
		generate_numbers = ->
			for i in [0..623]
				y = ((MT[i] & 0x80000000) >>> 31) + (0x7FFFFFFF & MT[ (i+1) % 624 ])
				MT[i] = MT[ (i+397) % 624 ] ^ (y >>> 1)
				if (y%2) is 1
					MT[i] = MT[i] ^ 2567483615
		a = Math.pow(2,31)
		b = a * 2
		next = ->
			if index is 0
				generate_numbers()
			y = MT[index] ^
				(y >>> 11) ^
				((y << 7) and 2636928640) ^
				((y << 15) and 4022730752) ^
				(y >>> 18)
			index = (index + 1) % 624
			(y + a) / b
		$.defineProperty next, "seed",
			set: (v) -> init_generator(v)
		
		next.seed = +new Date()
		return $.extend next,
			real: real = (min, max) ->
				if not min?
					[min,max] = [0,1.0]
				if not max?
					[min,max] = [0,min]
				($.random() * (max - min)) + min
			integer: integer = (min, max) -> Math.floor $.random.real(min,max)
			string: string = (len, prefix="") ->
				prefix += $.random.element(alphabet) while prefix.length < len
				prefix
			coin: coin = (balance=.5) -> $.random() <= balance
			element: (arr, weights) ->
				if weights?
					w = $(weights)
					w = w.scale(1.0/w.sum())
					i = 0
					sorted = $(arr).map((x) -> {v: x, w: w[i++] }).sortBy (x) -> -x.w
					r = $.random.real(0.00001,.999999) # never exactly 0.0 or 1.0
					sum = 0
					for item in sorted
						return item.v if (sum += item.w) >= r
				return arr[$.random.integer 0, arr.length]
			gaussian: gaussian = (mean=0.5, ssig=0.12) -> # paraphrased from Wikipedia
				while true
					u = $.random()
					v = 1.7156 * ($.random() - 0.5)
					x = u - 0.449871
					y = Math.abs(v) + 0.386595
					q = (x*x) + y*(0.19600*y-0.25472*x)
					break unless q > 0.27597 and (q > 0.27846 or (v*v) > (-4*Math.log(u)*u*u))
				return mean + ssig*v/u
			dice: dice = (n, faces) -> # a 2d8 is dice(2,8)
				$( die(faces) for _ in [0...n] by 1 )
			die: die = (faces) ->
				$.random.integer(1,faces+1)
$.plugin
	depends: "core"
	provides: "request-queue"
, ->
	$:
		RequestQueue: class RequestQueue
			constructor: (requester) ->
				@requester = requester ? try require 'request'
				@interval = null
				@queue = []
			tick: ->
				for i in [0...n = Math.min @queue.length, @perTick] by 1
					@requester @queue.shift()...
			start: (@perTick=1, interval=100) ->
				@stop() if @interval?
				@interval = setInterval (=> do @tick), interval
				@
			stop: stop = ->
				clearInterval @interval
				@interval = null
				@
			close: stop
			request: (args...) ->
				@queue.push args
				@
			post: (opts, callback = $.identity) ->
				@queue.push [($.extend opts, method: "POST"), callback]
				@
			get: (opts, callback = $.identity) ->
				@queue.push [($.extend opts, method: "GET"), callback]
				@
$.plugin
	provides: "sendgrid"
	depends: "config"
, ->
	try
		nodemailer = require 'nodemailer'
	catch err
		`return`
	transport = null
	openTransport = ->
		transport or= nodemailer.createTransport 'SMTP',
			service: 'SendGrid'
			auth:
				user: $.config.get 'SENDGRID_USERNAME'
				pass: $.config.get 'SENDGRID_PASSWORD' # this should be set manually by 'heroku config:add SENDGRID_PASSWORD=xyz123'
	closeTransport = ->
		transport?.close()
		transport = null
	$:
		sendMail: (mail, callback) ->
			mail.transport ?= openTransport()
			mail.from ?= $.config.get 'EMAILS_FROM'
			mail.bcc ?= $.config.get 'EMAILS_BCC'
			if $.config.get('SENDGRID_ENABLED', 'true') is 'true'
				nodemailer.sendMail mail, (err) ->
					if mail.close
						closeTransport()
					callback(err)
			else
				if mail.close
					closeTransport()
				callback(false) # Reply as if an email was sent
$.plugin
	provides: "sortBy,sortedIndex"
, ->
	$:
		sortedIndex: (array, item, iterator) ->
			cmp = switch $.type iterator
				when "string" then (a,b) -> a[iterator] < b[iterator]
				when "function" then (a,b) -> iterator(a) < iterator(b)
				else (a,b) -> a < b
			hi = array.length
			lo = 0
			while lo < hi
				mid = (hi + lo)>>>1
				if cmp(array[mid], item)
					lo = mid + 1
				else
					hi = mid
			return lo
	sortBy: (iterator) ->
		a = $()
		for item in @
			n = $.sortedIndex a, item, iterator
			a.splice n, 0, item
		a
	sortedInsert: (item, iterator) ->
		@splice ($.sortedIndex @, item, iterator), 0, item
		@
		
$.plugin
	provides: "string"
	depends: "function"
, ->
	safer = (f) ->
		(a...) ->
			try return f(a...)
			catch err then return "[Error: #{err.message}]"
	$.type.extend
		unknown:
			string: safer (o) -> o.toString?() ? String(o)
			repr: safer (o) -> $.type.lookup(o).string(o)
			number: safer (o) -> parseFloat String o
		null: { string: -> "null" }
		undefined: { string: -> "undefined" }
		string:
			number: safer parseFloat
			repr:   (s) -> "'#{s}'"
		array:  { string: safer (a) -> "[" + ($.toString(x) for x in a).join(",") + "]" }
		object:
			string: safer (o) ->
				ret = []
				for k of o
					try
						v = o[k]
					catch err
						v = "[Error: #{err.message}]"
					ret.push "#{k}:#{$.toString v}"
				"{" + ret.join(', ') + "}"
			repr: safer (o) ->
				ret = []
				for k of o
					try
						v = o[k]
					catch err
						v = "[Error: #{err.message}]"
					ret.push "#{k}:#{$.toRepr v}"
				"{" + ret.join(', ') + "}"
		function:
			string: (f) -> f.toString().replace(/^([^{]*){(?:.|\n|\r)*}$/, '$1{ ... }')
			repr: (f) -> f.toString()
		number:
			repr:   (n) -> String(n)
			string: safer (n) ->
				switch true
					when n.precision? then n.toPrecision(n.precision)
					when n.fixed? then n.toFixed(n.fixed)
					else String(n)
	return {
		$:
			toString: (x) ->
				if not x? then "function Bling(selector, context) { [ ... ] }"
				else
					try
						$.type.lookup(x).string(x)
					catch err
						"[Error: #{err.message}]"
			toRepr: (x) -> $.type.lookup(x).repr(x)
			px: (x, delta=0) -> x? and (parseInt(x,10)+(parseInt(delta)|0))+"px"
			capitalize: (name) -> (name.split(" ").map (x) -> x[0].toUpperCase() + x.substring(1).toLowerCase()).join(" ")
			slugize: (phrase) -> phrase
				.toLowerCase()
				.replace(/^\s+/, '')
				.replace(/\s+$/, '')
				.replace(/\t/g, ' ')
				.replace(/[^A-Za-z0-9 ]/g, '')
				.replace(/\s+/g,'-')
			dashize: (name) ->
				ret = ""
				for i in [0...(name?.length|0)]
					c = name.charCodeAt i
					if 91 > c > 64
						c += 32
						ret += '-'
					ret += String.fromCharCode(c)
				ret
			camelize: (name) ->
				name.split('-')
				while (i = name?.indexOf('-')) > -1
					name = $.stringSplice(name, i, i+2, name[i+1].toUpperCase())
				name
			padLeft: (s, n, c = " ") ->
				while s.length < n
					s = c + s
				s
			padRight: (s, n, c = " ") ->
				while s.length < n
					s = s + c
				s
			stringTruncate: (s, n, c = "...") ->
				s = s.split(' ')
				r = []
				while n > 0
					x = s.shift()
					n -= x.length
					if n >= 0
						r.push x
				r.join('') + c
			stringCount: (s, x, i = 0, n = 0) ->
				if (j = s.indexOf x,i) > i-1
					$.stringCount s, x, j+1, n+1
				else n
			stringSplice: (s, i, j, n) ->
				nn = s.length
				end = j
				if end < 0
					end += nn
				start = i
				if start < 0
					start += nn
				s.substring(0,start) + n + s.substring(end)
			checksum: (s) ->
				a = 1; b = 0
				for i in [0...s.length]
					a = (a + s.charCodeAt(i)) % 65521
					b = (b + a) % 65521
				(b << 16) | a
			repeat: (x, n=2) ->
				switch true
					when n is 1 then x
					when n < 1 then ""
					when $.is "string", x then $.zeros(n).map(-> x).join('')
					else $.zeros(n).map(-> x)
			stringBuilder: ->
				if $.is("global", @) then return new $.stringBuilder()
				items = []
				@length   = 0
				@append   = (s) => items.push s; @length += s?.toString().length|0
				@prepend  = (s) => items.splice 0,0,s; @length += s?.toString().length|0
				@clear    = ( ) => ret = @toString(); items = []; @length = 0; ret
				@toString = ( ) => items.join("")
				@
		toString: -> $.toString @
		toRepr: -> $.toRepr @
	}
$.plugin
	provides: "symbol"
	depends: "type"
, ->
	symbol = null
	cache = {}
	g = $.global
	g.Bling = Bling
	if module?
		module.exports = Bling
	$.defineProperty $, "symbol",
		set: (v) ->
			g[symbol] = cache[symbol]
			cache[symbol = v] = g[v]
			g[v] = Bling
		get: -> symbol
	return $:
		symbol: "$"
		noConflict: ->
			Bling.symbol = "Bling"
			Bling
$.plugin
	provides: "StateMachine"
, ->
	$: StateMachine: class StateMachine
		constructor: (stateTable) ->
			@debug = false
			@reset()
			@table = stateTable
			Object.defineProperty @, "modeline",
				get: -> @table[@_mode]
			Object.defineProperty @, "mode",
				set: (m) ->
					@_lastMode = @_mode
					@_mode = m
					if @_mode isnt @_lastMode and @modeline? and 'enter' of @modeline
						ret = @modeline['enter'].call @
						while $.is("function",ret)
							ret = ret.call @
					m
				get: -> @_mode
		reset: ->
			@_mode = null
			@_lastMode = null
		GO: (m) -> -> @mode = m
		@GO: (m, enter=false) ->
			->
				if enter # force enter to trigger
					@_mode = null
				@mode = m
		
		tick: (c) ->
			row = @modeline
			if not row?
				ret = null
			else if c of row
				ret = row[c]
			else if 'def' of row
				ret = row['def']
			while $.is "function",ret
				ret = ret.call @, c
			ret
		run: (inputs) ->
			@mode = 0
			for c in inputs
				ret = @tick(c)
			if $.is "function",@modeline?.eof
				ret = @modeline.eof.call @
			while $.is "function",ret
				ret = ret.call @
			@reset()
			return @
$.plugin
	provides: "synth"
	depends: "StateMachine, type"
, ->
	class SynthMachine extends $.StateMachine
		basic =
			"#": @GO 2
			".": @GO 3, true
			"[": @GO 4
			'"': @GO 6
			"'": @GO 7
			" ": @GO 8
			"\t": @GO 8
			"\n": @GO 8
			"\r": @GO 8
			",": @GO 10
			"+": @GO 11
			eof: @GO 13
		@STATE_TABLE = [
			{ # 0: START
				enter: ->
					@tag = @id = @cls = @attr = @val = @text = ""
					@attrs = {}
					@GO 1
			},
			$.extend({ # 1: read a tag name
				def: (c) -> @tag += c
			}, basic),
			$.extend({ # 2: read an #id
				def: (c) -> @id += c
			}, basic),
			$.extend({ # 3: read a .class name
				enter: -> @cls += " " if @cls.length > 0
				def: (c) -> @cls += c
			}, basic),
			{ # 4: read an attribute name (left-side)
				"=": @GO 5
				"]": -> @attrs[@attr] = @val; @attr = @val = ""; @GO 1
				def: (c) -> @attr += c
				eof: @GO 12
			},
			{ # 5: read an attribute value (right-side)
				"]": -> @attrs[@attr] = @val; @attr = @val = ""; @GO 1
				def: (c) -> @val += c
				eof: @GO 12
			},
			{ # 6: read double-quoted text
				'"': @GO 8
				def: (c) -> @text += c
				eof: @GO 12
			},
			{ # 7: read single-quoted text
				"'": @GO 8
				def: (c) -> @text += c
				eof: @GO 12
			},
			{ # 8: emit text and continue
				enter: ->
					@emitNode() if @tag
					@emitText() if @text
					@GO 0
			},
			{}, # 9: empty
			{ # 10: emit node and start a new tree
				enter: ->
					@emitNode()
					@cursor = null
					@GO 0
			},
			{ # 11: emit node and step sideways to create a sibling
				enter: ->
					@emitNode()
					@cursor = @cursor?.parentNode
					@GO 0
			},
			{ # 12: ERROR
				enter: -> throw new Error "Error in synth expression: #{@input}"
			},
			{ # 13: FINALIZE
				enter: ->
					@emitNode() if @tag
					@emitText() if @text
			}
		]
		constructor: ->
			super(SynthMachine.STATE_TABLE)
			@fragment = @cursor = document.createDocumentFragment()
		emitNode: ->
			if @tag
				node = document.createElement @tag
				node.id = @id or null
				node.className = @cls or null
				for k of @attrs
					node.setAttribute k, @attrs[k]
				@cursor.appendChild node
				@cursor = node
		emitText: ->
			@cursor.appendChild $.type.lookup("<html>").node(@text)
			@text = ""
	return {
		$:
			synth: (expr) ->
				s = new SynthMachine()
				s.run(expr)
				if s.fragment.childNodes.length == 1
					$(s.fragment.childNodes[0])
				else
					$(s.fragment)
	}
do ($ = Bling) ->
	$.plugin () -> # Template plugin, pythonic style: %(value).2f
		current_engine = null
		engines = {}
		template = {
			register_engine: (name, render_func) ->
				engines[name] = render_func
				if not current_engine?
					current_engine = name
			render: (text, args) ->
				if current_engine of engines
					engines[current_engine](text, args)
		}
		template.__defineSetter__ 'engine', (v) ->
			if not v of engines
				throw new Error "invalid template engine: #{v} not one of #{Object.Keys(engines)}"
			else
				current_engine = v
		template.__defineGetter__ 'engine', () -> current_engine
		return {
			name: 'Template'
			$:
				template: template
		}
	
	$.template.register_engine 'null', (() ->
		return (text, values) ->
			text
	)()
	match_forward = (text, find, against, start, stop = -1) -> # a brace-matcher, useful in most template parsing steps
		count = 1
		if stop < 0
			stop = text.length + 1 + stop
		for i in [start...stop] by 1
			t = text[i]
			if t is against
				count += 1
			else if t is find
				count -= 1
			if count is 0
				return i
		return -1
	$.template.register_engine 'pythonic', (() ->
		type_re = /([0-9#0+-]*)\.*([0-9#+-]*)([diouxXeEfFgGcrsqm])((?:.|\n)*)/ # '%.2f' becomes [key, pad, fixed, type, remainder]
		chunk_re = /%[\(\/]/
		compile = (text) ->
			chunks = text.split chunk_re
			n = chunks.length
			ret = [chunks[0]]
			j = 1 # insert marker into ret
			for i in [1...n] by 1
				end = match_forward chunks[i], ')', '(', 0, -1
				if end is -1
					return "Template syntax error: unmatched '%(' starting at: #{chunks[i].substring(0,15)}"
				key = chunks[i].substring 0, end
				rest = chunks[i].substring end
				match = type_re.exec rest
				if match is null
					return "Template syntax error: invalid type specifier starting at '#{rest}'"
				rest = match[4]
				ret[j++] = key
				ret[j++] = match[1]|0
				ret[j++] = match[2]|0
				ret[j++] = match[3]
				ret[j++] = rest
			return ret
		compile.cache = {}
		render = (text, values) -> # $.render(/t/, /v/) - replace markers in string /t/ with values from /v/
			cache = compile.cache[text] # get the cached version
			if not cache?
				cache = compile.cache[text] = compile(text) # or compile and cache it
			output = [cache[0]] # the first block is always just text
			j = 1 # insert marker into output
			n = cache.length
			for i in [1..n-5] by 5
				[key, pad, fixed, type, rest] = cache[i..i+4]
				value = values[key]
				if not value?
					value = "missing value: #{key}"
				switch type
					when 'd'
						output[j++] = "" + parseInt(value, 10)
					when 'f'
						output[j++] = parseFloat(value).toFixed(fixed)
					when 's'
						output[j++] = "" + value
					else
						output[j++] = "" + value
				if pad > 0
					output[j] = String.PadLeft output[j], pad
				output[j++] = rest
			output.join ""
		return render
	)()
	$.template.register_engine 'js-eval', (() -> # work in progress...
		class TemplateMachine extends $.StateMachine
			@STATE_TABLE = [
				{ # 0: START
					enter: () ->
						@data = []
						@GO(1)
				},
				{ # 1: read anything
				}
			]
			
		return (text, values) ->
			text
	)()
$.plugin
	provides: "throttle"
	depends: "core"
, ->
	$:
		throttle: (ms, f) ->
			last = 0
			(a...) ->
				gap = $.now - last
				if gap > ms
					last += gap
					return f.apply @,a
				null
		debounce: (ms, f) ->
			timeout = null
			(a...) ->
				clearTimeout timeout
				setTimeout (=>
					f.apply @, arguments
				), ms
$.plugin
	depends: 'type'
	provides: 'TNET'
, -> # TnetStrings plugin
	parseOne = (data) ->
		i = data.indexOf ":"
		if i > 0
			len = parseInt data[0...i], 10
			item = data[i+1...i+1+len]
			type = data[i+1+len]
			extra = data[i+len+2...]
			item = switch type
				when "#" then Number(item)
				when "'" then String(item)
				when "!" then (item is "true")
				when "~" then null
				when "]" then parseArray(item)
				when "}" then parseObject(item)
			return [item, extra]
		return undefined
	parseArray = (x) ->
		data = []
		while x.length > 0
			[one, x] = parseOne(x)
			data.push(one)
		data
	parseObject = (x) ->
		data = {}
		while x.length > 0
			[key, x] = parseOne(x)
			[value, x] = parseOne(x)
			data[key] = value
		data
	$:
		TNET:
			stringify: (x) ->
				[data, type] = switch $.type x
					when "number" then [String(x), "#"]
					when "string" then [x, "'"]
					when "function" then [String(x), "'"]
					when "boolean" then [String(not not x), "!"]
					when "null" then ["", "~"]
					when "undefined" then ["", "~"]
					when "array" then [($.TNET.stringify(y) for y in x).join(''), "]"]
					when "object" then [($.TNET.stringify(y)+$.TNET.stringify(x[y]) for y of x).join(''), "}"]
				return (data.length|0) + ":" + data + type
			parse: (x) ->
				parseOne(x)?[0]
$.plugin
	provides: "trace"
	depends: "function,type"
, ->
	$.type.extend
		unknown: { trace: $.identity }
		object:  { trace: (label, o, tracer) -> (o[k] = $.trace(o[k], "#{label}.#{k}", tracer) for k in Object.keys(o)); o }
		array:   { trace: (label, o, tracer) -> (o[i] = $.trace(o[i], "#{label}[#{i}]", tracer) for i in [0...o.length] by 1); o }
		function:
			trace: (label, f, tracer) ->
				label or= f.name
				r = (a...) ->
					tracer "#{@name or $.type(@)}.#{label}(#{$(a).map($.toRepr).join ','})"
					f.apply @, a
				r.toString = -> "{Trace '#{label}' of #{f.toString()}"
				r
	return $: trace: (label, o, tracer) ->
		if not $.is "string", label
			[tracer, o] = [o, label]
		tracer or= $.log
		label or= ""
		$.type.lookup(o).trace(label, o, tracer)
$.plugin
	depends: "dom"
, ->
	COMMASEP = ", "
	speeds = # constant speed names
		"slow": 700
		"medium": 500
		"normal": 300
		"fast": 100
		"instant": 0
		"now": 0
	accel_props_re = /(?:scale(?:3d)*|translate(?:[XYZ]|3d)*|rotate(?:[XYZ]|3d)*)/
	updateDelay = 30 # ms to wait for DOM changes to apply
	testStyle = document.createElement("div").style
	transformProperty = "transform"
	transitionProperty = "transition-property"
	transitionDuration = "transition-duration"
	transitionTiming = "transition-timing-function"
	if "WebkitTransform" of testStyle
		transformProperty = "-webkit-transform"
		transitionProperty = "-webkit-transition-property"
		transitionDuration = "-webkit-transition-duration"
		transitionTiming = "-webkit-transition-timing-function"
	else if "MozTransform" of testStyle
		transformProperty = "-moz-transform"
		transitionProperty = "-moz-transition-property"
		transitionDuration = "-moz-transition-duration"
		transitionTiming = "-moz-transition-timing-function"
	else if "OTransform" of testStyle
		transformProperty = "-o-transform"
		transitionProperty = "-o-transition-property"
		transitionDuration = "-o-transition-duration"
		transitionTiming = "-o-transition-timing-function"
	return {
		$:
			duration: (speed) ->
				d = speeds[speed]
				return d if d?
				return parseFloat speed
		transform: (end_css, speed, easing, callback) ->
			if $.is("function",speed)
				callback = speed
				speed = easing = null
			else if $.is("function",easing)
				callback = easing
				easing = null
			speed ?= "normal"
			easing or= "ease"
			duration = $.duration(speed) + "ms"
			props = []
			trans = ""
			css = {}
			for i of end_css
				if accel_props_re.test(i)
					ii = end_css[i]
					if ii.join
						ii = $(ii).px().join COMMASEP
					else if ii.toString
						ii = ii.toString()
					trans += " " + i + "(" + ii + ")"
				else css[i] = end_css[i]
			(props.push i) for i of css
			if trans
				props.push transformProperty
			css[transitionProperty] = props.join COMMASEP
			css[transitionDuration] = props.map(-> duration).join COMMASEP
			css[transitionTiming] = props.map(-> easing).join COMMASEP
			if trans
				css[transformProperty] = trans
			@css css
			if callback
				@delay duration, $.bound @, callback
		hide: (callback) -> # .hide() - each node gets display:none
			@each ->
				if @style
					@_display = "" # stash the old display
					if @style.display is not "none"
						@_display = @syle.display
					@style.display = "none"
			.trigger("hide")
			if callback
				@delay updateDelay, $.bound @, callback
			@
		show: (callback) -> # .show() - show each node
			@each ->
				if @style
					@style.display = @_display
					delete @_display
			.trigger("show")
			if callback
				@delay updateDelay, $.bound @, callback
			@
		toggle: (callback) -> # .toggle() - show each hidden node, hide each visible one
			@weave(@css("display"))
				.fold((display, node) ->
					if display is "none"
						node.style.display = node._display or ""
						delete node._display
						$(node).trigger "show"
					else
						node._display = display
						node.style.display = "none"
						$(node).trigger "hide"
					node
				).delay(updateDelay, $.bound @, callback)
		fadeIn: (speed, callback) -> # .fadeIn() - fade each node to opacity 1.0
			@.css('opacity','0.0')
				.show ->
					@transform {
						opacity:"1.0",
						translate3d: [0,0,0]
					}, speed, callback
		fadeOut: (speed, callback, x = 0.0, y = 0.0) -> # .fadeOut() - fade each node to opacity:0.0
			@transform {
				opacity:"0.0",
				translate3d:[x,y,0.0]
			}, speed, -> @hide($.bound @, callback)
		fadeLeft: (speed, callback) -> @fadeOut speed, callback, "-"+@width().first(), 0.0
		fadeRight: (speed, callback) -> @fadeOut speed, callback, @width().first(), 0.0
		fadeUp: (speed, callback) -> @fadeOut speed, callback, 0.0, "-"+@height().first()
		fadeDown: (speed, callback)  -> @fadeOut speed, callback, 0.0, @height().first()
	}
$.plugin
	provides: "type"
, ->
	isType = (T, o) ->
		if not o? then T in [o,"null","undefined"]
		else (o.constructor? and (o.constructor is T or o.constructor.name is T)) or
			Object::toString.apply(o) is "[object #{T}]" or
			isType T, o.__proto__ # recursive
	inherit = (parent, obj) ->
		return unless obj?
		if typeof parent is "function"
			parent = parent.prototype
		if parent.__proto__ in [Object.prototype, null, undefined]
			parent.__proto__ = obj.__proto__
		obj.__proto__ = parent
		obj
	_type = do ->
		cache = {}
		base =
			name: 'unknown'
			match: (o) -> true
		order = []
		register = (name, data) ->
			order.unshift name if not (name of cache)
			cache[data.name = name] = if (base isnt data) then (inherit base, data) else data
			cache[name][name] = (o) -> o
		_extend = (name, data) ->
			if typeof name is "string"
				cache[name] ?= register name, {}
				cache[name] = extend cache[name], data
			else if typeof name is "object"
				(_extend k, name[k]) for k of name
		lookup = (obj) ->
			for name in order
				if cache[name]?.match.call obj, obj
					return cache[name]
		register "unknown",   base
		register "object",    match: (o) -> typeof o is "object"
		register "error",     match: (o) -> isType 'Error', o
		register "regexp",    match: (o) -> isType 'RegExp', o
		register "string",    match: (o) -> typeof o is "string" or isType String, o
		register "number",    match: (o) -> (isType Number, o) and o isnt NaN
		register "bool",      match: (o) -> typeof o is "boolean" or try String(o) in ["true","false"]
		register "array",     match: Array.isArray or (o) -> isType Array, o
		register "function",  match: (o) -> typeof o is "function"
		register "global",    match: (o) -> typeof o is "object" and 'setInterval' of @ # Use the same crude method as jQuery for detecting the window, not very safe but it does work in Node and the browser
		register "arguments", match: (o) -> try 'callee' of o and 'length' of o
		register "undefined", match: (x) -> x is undefined
		register "null",      match: (x) -> x is null
		return extend ((o) -> lookup(o).name),
			register: register
			lookup: lookup
			extend: _extend
			is: (t, o) -> cache[t]?.match.call o, o
			as: (t, o, rest...) -> lookup(o)[t]?(o, rest...)
	_type.extend
		unknown:   { array: (o) -> [o] }
		null:      { array: (o) -> [] }
		undefined: { array: (o) -> [] }
		array:     { array: (o) -> o }
		number:    { array: (o) -> Bling.extend new Array(o), length: 0 }
		arguments: { array: (o) -> Array::slice.apply o }
	maxHash = Math.pow(2,32)
	_type.register "bling",
		match:  (o) -> o and isType Bling, o
		array:  (o) -> o.toArray()
		hash:   (o) -> o.map(Bling.hash).reduce (a,x) -> ((a*a)+x) % maxHash
		string: (o) -> Bling.symbol + "([" + o.map((x) -> $.type.lookup(x).string(x)).join(", ") + "])"
		repr: (o) -> Bling.symbol + "([" + o.map((x) -> $.type.lookup(x).repr(x)).join(", ") + "])"
	$:
		inherit: inherit
		extend: extend
		defineProperty: (o, name, opts) ->
			Object.defineProperty o, name, extend({ configurable: true, enumerable: true }, opts)
			o
		isType: isType
		type: _type
		is: _type.is
		as: _type.as
		isSimple: (o) -> _type(o) in ["string", "number", "bool"]
		isEmpty: (o) -> o in ["", null, undefined] or o.length is 0 or (typeof o is "object" and Object.keys(o).length is 0)
	defineProperty: (name, opts) -> @each -> $.defineProperty @, name, opts
$.plugin
	depends: 'math'
	provides: 'units'
, ->
	units = $ ["px","pt","pc","em","%","in","cm","mm","ex","lb","kg","yd","ft","m", ""]
	UNIT_RE = null
	do makeUnitRegex = ->
		joined = units.filter(/.+/).join '|'
		UNIT_RE = new RegExp "(\\d+\\.*\\d*)((?:#{joined})/*(?:#{joined})*)"
	parseUnits = (s) ->
		if UNIT_RE.test(s)
			return UNIT_RE.exec(s)[2]
		""
	conv = (a,b) ->
		[numer_a, denom_a] = a.split '/'
		[numer_b, denom_b] = b.split '/'
		if denom_a? and denom_b?
			return conv(denom_b, denom_a) * conv(numer_a, numer_b)
		if a of conv and (b of conv[a])
			return conv[a][b]()
		0
	locker = (x) -> -> x
	fillConversions = ->
	setConversion = (from, to, f) ->
		conv[from] or= {}
		conv[from][to] = f
		if units.indexOf(from) is -1
			units.push from
		if units.indexOf(to) is -1
			units.push to
		makeUnitRegex()
		fillConversions()
	initialize = ->
		setConversion 'pc', 'pt', -> 12
		setConversion 'in', 'pt', -> 72
		setConversion 'in', 'px', -> 96
		setConversion 'in', 'cm', -> 2.54
		setConversion 'm', 'ft', -> 3.281
		setConversion 'yd', 'ft', -> 3
		setConversion 'cm', 'mm', -> 10
		setConversion 'm', 'cm', -> 100
		setConversion 'm', 'meter', -> 1
		setConversion 'm', 'meters', -> 1
		setConversion 'ft', 'feet', -> 1
		setConversion 'km', 'm', -> 1000
		setConversion 'em', 'px', ->
			w = 0
			try
				x = $("<span style='font-size:1em;visibility:hidden'>x</span>").appendTo("body")
				w = x.width().first()
				x.remove()
			w
		setConversion 'ex', 'px', ->
			w = 0
			try
				x = $("<span style='font-size:1ex;visibility:hidden'>x</span>").appendTo("body")
				w = x.width().first()
				x.remove()
			w
		setConversion 'ex', 'em', -> 2
		setConversion 'rad', 'deg', -> 57.3
		setConversion 's', 'sec', -> 1
		setConversion 's', 'ms', -> 1000
		setConversion 'ms', 'ns', -> 1000000
		setConversion 'min', 'sec', -> 60
		setConversion 'hr', 'min', -> 60
		setConversion 'hr', 'hour', -> 1
		setConversion 'hr', 'hours', -> 1
		setConversion 'day', 'hr', -> 24
		setConversion 'day', 'days', -> 1
		setConversion 'y', 'year', -> 1
		setConversion 'y', 'years', -> 1
		setConversion 'y', 'd', -> 365.25
		setConversion 'g', 'gram', -> 1
		setConversion 'g', 'grams', -> 1
		setConversion 'kg', 'g', -> 1000
		setConversion 'lb', 'g', -> 453.6
		setConversion 'lb', 'oz', -> 16
		setConversion 'f', 'frame', -> 1
		setConversion 'f', 'frames', -> 1
		setConversion 'sec', 'f', -> 60
		do fillConversions = ->
			conv[''] = {}
			one = locker 1.0
			for a in units
				conv[a] or= {}
				conv[a][a] = conv[a][''] = conv[''][a] = one
			infered = 1
			while infered > 0
				infered = 0
				for a in units when a isnt ''
					conv[a] or= {}
					for b in units when b isnt ''
						if (not conv a,b) and (conv b,a)
							conv[a][b] = locker 1.0/conv(b,a)
							infered += 1
						for c in units when c isnt ''
							if (conv a,b) and (conv b,c) and (not conv a,c)
								conv[a][c] = locker conv(a,b) * conv(b,c)
								infered += 1
			null
		$.units.enable = ->
	convertNumber = (number, unit) ->
		f = parseFloat(number)
		u = parseUnits(number)
		c = conv(u, unit)
		unless isFinite(c) and isFinite(f)
			return number
		"#{f * c}#{unit}"
	$.type.register "units",
		match: (x) -> typeof x is "string" and UNIT_RE.test(x)
		number: (x) -> parseFloat(x)
		string: (x) -> "'#{x}'"
	
	{
		$:
			units:
				enable: initialize
				set: setConversion
				get: conv
				convertTo: (unit, obj) -> convertNumber(obj, unit)
		convertTo: (unit) -> @map (x) -> convertNumber(x, unit)
		unitMap: (f) ->
			@map (x) ->
				f.call((n = parseFloat x), n) + parseUnits x
	}
$.plugin
	provides: "unittest"
	depends: "core,function"
, ->
	testCount = passCount = failCount = 0
	failed = []
	invokeTest = (group, name, func) ->
		return if not $.is "function", func
		_log = (msg) -> $.log "#{group}: #{name}... #{msg}"
		shouldFail = name.toLowerCase().indexOf("fail") isnt -1
		done = $.once (err) ->
			testCount--
			if (!!err isnt shouldFail)
				_log "fail: #{err}"
				failCount++
				failed.push name
			else
				_log "pass"
				passCount++
				$.provide name
		f = (done) ->
			try func(done)
			catch err then done(err)
			finally
				if name.toLowerCase().indexOf("async") is -1 then done()
		testCount++
		try f(done)
		catch err then done(err)
	testReport = $.once ->
		$.log "Passed: #{passCount} Failed: #{failCount} [#{failed}]"
		if failCount > 0
			try process.exit(failCount)
	$:
		approx: (a, b, margin=.1) -> Math.abs(a - b) < margin
		assert: (cnd, msg = "no message") -> if not cnd then throw new Error "Assertion failed: #{msg}"
		assertEqual: (a, b, label) ->
			if a isnt b
				throw Error "#{label or ''} (#{a?.toString()}) should equal (#{b?.toString()})"
		assertArrayEqual: (a, b, label) ->
			for i in [0...a.length] by 1
				try
					$.assertEqual(a[i], b[i], label)
				catch err
					throw Error "#{label or ''} #{a?.toString()} should equal #{b?.toString()}"
		testGroup: (name, funcs) ->
			interval = setInterval (-> if testCount is 0 then clearInterval(interval); testReport()), 50
			for k,func of funcs
				invokeTest(name, k, func)
	assertEqual: (args...) ->
		if args.length > 1 # short-cut the trivial cases
			args = args.map (x) => # call any functions passed as arguments
				if $.is "function", x then x.call(@,@) else x
			a = args[0]
			for i in [1...args.length]
				$.assertEqual a, args[i]
		return @
$.plugin
	depends: 'dialog'
	provides: 'wizard'
, ->
	$: wizard: (slides...) ->
		if slides.length is 1 and $.type(slides[0]) in ['array','bling']
			slides = slides[0]
		currentSlide = 0
		modal = $.dialog(slides[0]).select('parentNode')
		dialogs = []
		slideChanger = (delta) -> switch slides.length
			when 0 then $.identity
			else ->
				newSlide = (currentSlide + delta) % slides.length
				while newSlide < 0
					newSlide += slides.length
				return if newSlide is currentSlide
				$.log "slideChange: #{currentSlide} -> #{newSlide}"
				currentDialog = $ dialogs[currentSlide]
				newDialog = $ dialogs[newSlide]
				width = currentDialog.width()[0]
				newLeft = if delta < 0 then window.innerWidth - width else 0
				$.log "newLeft: #{$.px newLeft}"
				currentDialog.removeClass('wiz-active')
					.css(left: $.px newLeft)
					.fadeOut()
				newDialog.addClass('wiz-active').css(
					opacity: 0
					display: 'block'
				).centerOn(modal).fadeIn()
				currentSlide = newSlide
		modal.delegate '.wiz-next', 'click', slideChanger(+1)
		modal.delegate '.wiz-back', 'click', slideChanger(-1)
		for slide in slides.slice(1)
			d = $.synth('div.dialog div.title + div.content').css
				left: $.px window.innerWidth
			slide = $.extend $.dialog.getDefaultOptions(), slide
			d.find('.title').append $.dialog.getContent slide.titleType, slide.title
			d.find('.content').append $.dialog.getContent slide.contentType, slide.content
			d.appendTo(modal).fadeOut(0)
		dialogs = modal.find('.dialog')
		dialogs.take(1).show()
		modal
