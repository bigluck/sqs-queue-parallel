module.exports = (grunt) ->
	grunt.initConfig
		pkg: grunt.file.readJSON 'package.json'
		usebanner:
			options:
				banner: """
					/**
					 * <%= pkg.name %> <%= pkg.version %> <https://github.com/bigluck/sqs-queue-parallel>
					 * <%= pkg.description %>
					 *
					 * Available under MIT license <https://github.com/bigluck/sqs-queue-parallel/raw/master/LICENSE>
					 */
					"""
				position: 'top'
				linkbreak: true
			dist:
				files:
					'dist/sqs-queue-parallel.js': 'dist/sqs-queue-parallel.js'
		coffee:
			dist:
				files:
					'dist/sqs-queue-parallel.js': 'src/sqs-queue-parallel.coffee'

	grunt.loadNpmTasks 'grunt-contrib-coffee'
	grunt.loadNpmTasks 'grunt-banner'

	grunt.registerTask 'default', [
		'coffee'
		'usebanner'
	]
	grunt.registerTask 'dist', [
		'coffee'
		'usebanner'
	]
