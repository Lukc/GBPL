#!/usr/bin/env moon

lfs = require "lfs"
yaml = require "lyaml"
argparse = require "argparse"

find_all = (where = ".") ->
	traversal = (where) ->
		for entry in lfs.dir where
			if entry\sub(1, 1) == "."
				continue

			entry = where .. "/" .. entry

			attributes, e = lfs.attributes entry

			unless attributes
				io.stderr\write e, "\n"
				continue

			if attributes.mode == "directory"
				traversal entry
			else
				if not entry\match("/gbpl.yml$")
					continue

				coroutine.yield entry, attributes

	coroutine.wrap -> traversal where

Index = class
	new: =>
		@stack = {1}

	next: =>
		l = @stack[#@stack]
		@stack[#@stack] = l + 1

	up: =>
		table.remove @stack

		@\next!

	down: =>
		table.insert @stack, 1

	clone: =>
		with Index!
			for i = 1, #@stack
				.stack[i] = @stack[i]

	__tostring: =>
		table.concat @stack, "."

Fragment = class
	new: (origin, index, data, dirname) =>
		@unit = origin.unit
		@year = origin.year
		@tags = origin.tags
		@author = origin.author
		@children = data.children
		@type = data.type
		@source = data.source
		@repository = dirname

		@index = index\clone!

	__tostring: =>
		"<Fragment: %s, %s, %s/%s, %s, %s>"\format(
			@index
			@type, @unit,
			@year,
			@source,
			if type(@author) == "table" (
				tostring(#@author) .. " authors"
			) else
				@author
		)

Document = class
	new: (filename) =>
		@dirname = filename\gsub("/gbpl%.yaml$", "")
		@filename = filename

		-- FIXME: error checking
		file, e = io.open filename, "r"
		unless file
			error e

		contentText, e = file\read "*all"
		unless contentText
			error e

		content = yaml.load contentText

		@fragments = {}
		@\push_fragments content, Index!, content.documents, @dirname

		file\close!

	push_fragments: (origin, index, documents, dirname) =>
		for i, data in ipairs documents
			fragment = Fragment origin, index, data, dirname

			table.insert @fragments, fragment

			if fragment.children
				index\down!
				@\push_fragments origin, index, fragment.children, dirname
				index\up!
			else
				index\next!

	__tostring: =>
		"<Document: %s>"\format @filename

parser = with argparse "helper", "Helper for the Great Free Pedagogical Library"
	with \command "l list"
		with \argument "repository"
			\args "?"

		\option "-i --index"
		\option "-t --type"
		\option "-y --year"
		\option "-u --unit"
		\option "-a --author"

	\command "e export"

arg = parser\parse!

if arg.l
	for f in find_all arg.repository
		document = Document f

		for _, fragment in ipairs document.fragments
			if arg.index
				if tostring(fragment.index) != arg.index
					continue

			if arg.type
				if string.lower(fragment.type) != string.lower(arg.type)
					continue

			if arg.unit
				if string.match string.lower(fragment.unit), string.lower(arg.unit)
					continue

			if arg.year
				if fragment.year != arg.year
					continue

			if arg.author
				if type(fragment.author) == "table"
					foundOne = false

					for author in *fragment.author
						if string.lower(author)\match string.lower(arg.author)
							foundOne = true

							break

					if not foundOne
						continue
				else
					if string.lower(fragment.author) != string.lower(arg.author)
						continue

			print fragment.repository\gsub("^%./", "") .. " " .. tostring(fragment)
elseif arg.e
	false -- FIXME: implement
else
	false -- FIXME: error

