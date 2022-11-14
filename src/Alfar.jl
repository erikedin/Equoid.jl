# Copyright 2022 Erik Edin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Alfar

include("Render.jl")

using GLFW
using ModernGL
using Alfar.Render

function run()
    # Create a window and its OpenGL context
    window = GLFW.CreateWindow(640, 480, "Alfar")

    # Make the window's context current
    GLFW.MakeContextCurrent(window)

    program, vao = Render.setupgraphics()

    starttime = time()

    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    glEnable(GL_DEPTH_TEST)

    # Camera variables
    cameraposition = (0f0, 0f0, 3f0)
    camerafront = (0f0, 0f0, -1f0)
    cameraup = (0f0, 1f0, 0f0)

    # Keyboard input time state
    deltatime = 0f0
    lastframetime = 0f0


    GLFW.SetKeyCallback(window, (_, key, scancode, action, mods) -> begin
        cameraspeed = 2.5f0 * deltatime
        cameraright = Render.normalize(Render.cross(camerafront, cameraup))

        if key == GLFW.KEY_W && action == GLFW.PRESS
            cameraposition += camerafront * cameraspeed
        end
        if key == GLFW.KEY_S && action == GLFW.PRESS
            cameraposition -= camerafront * cameraspeed
        end
        if key == GLFW.KEY_A && action == GLFW.PRESS
            cameraposition -= cameraright * cameraspeed
        end
        if key == GLFW.KEY_D && action == GLFW.PRESS
            cameraposition += cameraright * cameraspeed
        end

        if key == GLFW.KEY_ESCAPE && action == GLFW.PRESS
            GLFW.SetWindowShouldClose(window, true)
        end
    end)

    # Loop until the user closes the window
    while !GLFW.WindowShouldClose(window)
        glClearColor(0.2f0, 0.3f0, 0.3f0, 1.0f0)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

	    # Render here

        # Set alpha channel based on time
        timevalue = Float32(time() - starttime)
        # alpha = sin(2.0f0 * pi / 4.0f0 * timevalue) / 2.0f0 + 0.5f0

        angle = 2.0f0 * pi / 12.0f0 * timevalue
        # angle = -1f0*pi*5f0/8f0

        scaling = Render.scale(1.0f0, 1.0f0, 1.0f0)
        view = Render.lookat(cameraposition, cameraposition + camerafront, cameraup)
        projection = Render.perspective(0.25f0*pi, 640f0/480f0, 0.1f0, 100f0)

        use(program)

        uniform(program, "alpha", 1.0f0)
        uniform(program, "view", view)
        uniform(program, "projection", projection)

        glBindVertexArray(vao)
        cubepositions = [
            (0f0, 0f0, 0f0),
            (2f0, 5f0, -15f0),
            (-1.5f0, -2.2f0, -2.5f0),
            (-1.5f0, 0.2f0, -1.5f0),
        ]
        for (sx, sy, sz) in cubepositions
            translation = Render.translate(sx, sy, sz)
            rotation = Render.rotatex(angle+sx) * Render.rotatez(angle+sy)

            uniform(program, "model", translation * rotation * scaling)
            glDrawElements(GL_TRIANGLES, 18, GL_UNSIGNED_INT, C_NULL)
        end
        glBindVertexArray(0)

	    # Swap front and back buffers
	    GLFW.SwapBuffers(window)

        # Keep track of how long this frame took
        currentframe = time()
        deltatime = Float32(currentframe - lastframetime)
        lastframetime = currentframe

	    # Poll for and process events
	    GLFW.PollEvents()
    end

    GLFW.DestroyWindow(window)
end

end # module Alfar
