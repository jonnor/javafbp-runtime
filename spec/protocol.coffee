#     javafbp-runtime - FBP runtime protocol implementation for JavaFBP
#     (c) 2014 The Grid
#     javafbp-runtime may be freely distributed under the MIT license

utils = require './utils'
fs = require 'fs'

chai = require 'chai'

debug = process.env.JAVAFBP_TESTS_DEBUG?
# Used for checks which cannot be evaluated when running in debug,
# when we don't get the stdout of the runtime for instance.
itSkipDebug = if debug then it.skip else it

port = 3569 # FIXME: use other
describe 'NoFlo runtime API,', () ->
    runtime = new utils.RuntimeProcess port, debug
    ui = new utils.MockUi port

    outfile = null

    before (done) ->
        runtime.start ->
            f = () ->
                ui.connect()
                ui.on 'connected', () ->
                    done()
            setTimeout f, 1000

    after (done) ->
        ui.disconnect()
        ui.on 'disconnected', () ->
            runtime.stop () ->
                done()

    describe 'startup', ->
        it 'should not have produced any errors', ->
            chai.expect(runtime.popErrors()).to.eql []

    describe 'runtime info', ->
        info = null
        it 'should be returned on getruntime', (done) ->
            ui.send "runtime", "getruntime"
            ui.once 'runtime-info-changed', () ->
                info = ui.runtimeinfo
                chai.expect(info).to.be.an 'object'
                done()
        it 'type should be "javafbp"', ->
            chai.expect(info.type).to.equal "javafbp"
        it 'protocol version should be "0.4"', ->
            chai.expect(info.version).to.be.a "string"
            chai.expect(info.version).to.equal "0.4"
        it 'capabilities should include "protocol:component"', ->
            chai.expect(info.capabilities).to.be.an "array"
            chai.expect((info.capabilities.filter -> 'protocol:component')[0]).to.be.a "string"
        it 'capabilities should include "protocol:graph"', ->
            chai.expect((info.capabilities.filter -> 'protocol:graph')[0]).to.be.a "string"

    describe 'sending component list', ->
        it 'should return more than 50 components', (done) ->
            @timeout 2000
            ui.send "component", "list"
            ui.on 'component-added', (name, definition) ->
                numberOfComponents = Object.keys(ui.components).length
                if numberOfComponents == 50
                    done()
        it 'should contain core/Counter', ->
            chai.expect(ui.components['core/Counter']).to.be.an 'object'

        describe.skip 'core/Counter component', ->
            name = 'core/Counter'

            it 'should have a "input" buffer port', ->
                input = ui.components['gegl/crop'].inPorts.filter (p) -> p.id == 'input'
                chai.expect(input.length).to.equal 1
                chai.expect(input[0].type).to.equal "buffer"
            it 'should have a "output" buffer port', ->
                output = ui.components['gegl/crop'].outPorts.filter (p) -> p.id == 'output'
                chai.expect(output.length).to.equal 1
                chai.expect(output[0].type).to.equal "buffer"
            it 'should also have inports for properties "x", "y", "width" and "height"', ->
                c = ui.components['gegl/crop']
                chai.expect(Object.keys(c.inPorts).length).to.equal 5
                chai.expect((c.inPorts.filter (p) -> p.id == 'width')[0].type).to.equal 'number'
                chai.expect((c.inPorts.filter (p) -> p.id == 'height')[0].type).to.equal 'number'
                chai.expect((c.inPorts.filter (p) -> p.id == 'x')[0].type).to.equal 'number'
                chai.expect((c.inPorts.filter (p) -> p.id == 'y')[0].type).to.equal 'number'
            it 'should have default value for properties', ->
                c = ui.components['gegl/crop']
                chai.expect((c.inPorts.filter (p) -> p.id == 'width')[0].default).to.be.a.number
                chai.expect((c.inPorts.filter (p) -> p.id == 'width')[0].default).to.equal 10
                chai.expect((c.inPorts.filter (p) -> p.id == 'height')[0].default).to.equal 10
                chai.expect((c.inPorts.filter (p) -> p.id == 'x')[0].default).to.equal 0
                chai.expect((c.inPorts.filter (p) -> p.id == 'y')[0].default).to.equal 0
            it 'should have descriptions value for properties', ->
                c = ui.components['gegl/crop']
                p = (c.inPorts.filter (p) -> p.id == 'width')[0]
                chai.expect(p.description).to.be.a.string
                chai.expect(p.description).to.equal "Width"
                p = (c.inPorts.filter (p) -> p.id == 'x')[0]
                chai.expect(p.description).to.be.a.string
                chai.expect(p.description).to.equal "X"
            it 'should have icon "fa-crop"', ->
                chai.expect(ui.components['gegl/crop'].icon).to.equal 'crop'
            it 'should have description', ->
                chai.expect(ui.components['gegl/crop'].description).to.equal 'Crop a buffer'


    describe 'graph building', ->
        graph = 'graph1'
        # TODO: verify responses being received
        send = (protocol, cmd, pay, g) ->
            if graph?
                pay.graph = g
            ui.send protocol, cmd, pay
        ui.graph1 =
            send: (cmd, pay) ->
                send "graph", cmd, pay, graph

        outfile = 'spec/out/count-test.txt'
        it 'should not crash', (done) ->
            ui.send "graph", "clear", {id: graph}
            ui.graph1.send "addnode", {id: 'gen', component: 'examples/GenerateTestData'}
            ui.graph1.send "addnode", {id: 'counter', component: 'core/Counter'}
            ui.graph1.send "addnode", {id: 'out', component: 'core/WriteFile'}
            ui.graph1.send "addedge", {src: {node: 'gen', port: 'out'}, tgt: {node: 'counter', port: 'in'}}
            ui.graph1.send "addedge", {src: {node: 'counter', port: 'count'}, tgt: {node: 'out', port: 'in'}}
            ui.graph1.send "addinitial", {src: {data: 10}, tgt: {node: 'gen', port: 'count'}}
            ui.graph1.send "addinitial", {src: {data: outfile}, tgt: {node: 'out', port: 'destination'}}

            ui.send "runtime", "getruntime"
            ui.once 'runtime-info-changed', ->
                done()

        itSkipDebug 'should not have produced any errors', ->
            chai.expect(runtime.popErrors()).to.eql []

    describe 'starting the network', ->
        graph = 'graph1'

        it 'should respond with network started', (done) ->
            ui.send "network", "start", {graph: graph}
            ui.once 'network-running', (running) ->
                done() if running
        it 'should result in a created TXT file', (done) ->
            # TODO: 
            checkInterval = null
            checkExistence = ->
                fs.exists outfile, (exists) ->
                    done() if exists
                    clearInterval checkInterval
            checkInterval = setInterval checkExistence, 50
        itSkipDebug 'should not have produced any errors', ->
            chai.expect(runtime.popErrors()).to.eql []

    describe.skip 'stopping the network', ->
        graph = 'graph1'

        it 'should respond with network stopped', (done) ->
            ui.send "network", "stop", {graph: graph}
            ui.once 'network-running', (running) ->
                done() if not running
        itSkipDebug 'should not have produced any errors', ->
            chai.expect(runtime.popErrors()).to.eql []

    describe 'graph tear down', ->
        it 'should not crash', (done) ->

            ui.graph1.send "removenode", {id: 'gen'}
            ui.graph1.send "removenode", {id: 'counter'}
            ui.graph1.send "removenode", {id: 'out'}
            ui.graph1.send "removeedge", {src: {node: 'gen', port: 'out'}, tgt: {node: 'count', port: 'in'}}
            ui.graph1.send "removeedge", {src: {node: 'counter', port: 'count'}, tgt: {node: 'out', port: 'in'}}
            ui.graph1.send "removeinitial", { tgt: {node: 'gen', port: 'count'} }
            ui.graph1.send "removeinitial", { tgt: {node: 'out', port: 'destination'} }

            ui.send "runtime", "getruntime"
            ui.once 'runtime-info-changed', ->
                done()

        it.skip 'should give empty graph', (done) ->
            # TODO: use getgraph command to verify graph is now empty

        it 'should not have produced any errors', ->
            chai.expect(runtime.popErrors()).to.eql []


