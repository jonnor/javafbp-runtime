#     javafbp-runtime - FBP runtime protocol implementation for JavaFBP
#     (c) 2014 The Grid
#     javafbp-runtime may be freely distributed under the MIT license

child_process = require 'child_process'
EventEmitter = (require 'events').EventEmitter

websocket = require 'websocket'

# TODO: move into library, also use in MicroFlo and other FBP runtime implementations?
class MockUi extends EventEmitter

    constructor: (port) ->
        @client = new websocket.client()
        @connection = null
        @port = port

        @components = {}
        @runtimeinfo = {}
        @networkrunning = false
        @networkoutput = {}

        @client.on 'connect', (connection) =>
            @connection = connection
            @connection.on 'error', (error) =>
                throw error
            @connection.on 'close', (error) =>
                @emit 'disconnected'
            @connection.on 'message', (message) =>
                @handleMessage message
            @emit 'connected', connection

    handleMessage: (message) ->
        if not message.type == 'utf8'
            throw new Error "Received non-UTF8 message: " + message

        d = JSON.parse message.utf8Data
        if d.protocol == "component" and d.command == "component"
            id = d.payload.name
            @components[id] = d.payload
            @emit 'component-added', id, @components[id]
        else if d.protocol == "runtime" and d.command == "runtime"
            @runtimeinfo = d.payload
            @emit 'runtime-info-changed', @runtimeinfo
        else if d.protocol == "network" and d.command == "started"
            @networkrunning = true
            @emit 'network-running', @networkrunning
        else if d.protocol == "network" and d.command == "stopped"
            @networkrunning = false
            @emit 'network-running', @networkrunning
        else if d.protocol == "network" and d.command == "output"
            @networkoutput = d.payload
            @emit 'network-output', @networkoutput
        else
            console.log 'UI received unknown message', d

    connect: ->
        u = "ws://localhost:#{@port}/"
        # Note: does not use "noflo" subprotocol
        @client.connect u
    disconnect: ->
        @connection.close()
        @emit 'disconnected'

    send: (protocol, command, payload) ->
        msg =
            protocol: protocol
            command: command
            payload: payload || {}
        @sendMsg msg

    sendMsg: (msg) ->
        @connection.sendUTF JSON.stringify msg

isValidExit = (code, signal) ->
    success = code == 0
    planned = signal == 'SIGINT' or code == 130
    return success or planned

class RuntimeProcess
    constructor: (port, debug) ->
        @process = null
        @started = false
        @errors = []
        @port = port
        @debug = debug

    start: (success) ->
        exec = './runtime/build/install/runtime/bin/runtime'
        args = [] # FIXME: specify port
        if @debug
            console.log 'Debug mode: setup runtime yourself!', exec, args
            return success 0

        @process = child_process.spawn exec, args
        @process.on 'error', (err) ->
            throw err
        @process.on 'exit', (code, signal) =>
            if not isValidExit code, signal
                e = @errors.join '\n '
                m = "Runtime exited with non-zero code: #{code} #{signal}, errors(#{@errors.length}): " + e
                throw new Error m

        @process.stderr.on 'data', (d) =>
            output = d.toString()
            lines = output.split '\n'
            for line in lines
                err = line.trim()
                @errors.push err if err

        stdout = ""
        @process.stdout.on 'data', (d) ->
            if @debug
                console.log d
            stdout += d.toString()
            if (stdout.indexOf 'on port' != -1)
                if not @started
                    @started = true
                    return success process.pid

    stop: (callback) ->
        if @debug
            return callback()
        @process.once 'exit', (code, signal) ->
            if isValidExit code, signal
                return callback()
        @process.kill 'SIGINT'

    popErrors: ->
        errors = @errors
        @errors = []
        return errors

exports.MockUi = MockUi
exports.RuntimeProcess = RuntimeProcess

