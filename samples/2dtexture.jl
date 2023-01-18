# Copyright 2023 Erik Edin
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

using GLFW
using ModernGL

#
# Example mesh
# This is just a quad, defined by two triangles, at z = 0.5.
#

struct Mesh
    vao::GLuint
    numberofvertices::Int
end

function makequad() :: Mesh
    vertices = GLfloat[
        # Position                  # Texture coordinate
         0.5f0, -0.5f0,  0.5f0,     1.0f0, 0.0f0, # Right bottom
         0.5f0,  0.5f0,  0.5f0,     1.0f0, 1.0f0, # Right top
        -0.5f0,  0.5f0,  0.5f0,     0.0f0, 1.0f0, # Left  top
         0.5f0, -0.5f0,  0.5f0,     1.0f0, 0.0f0, # Right bottom
        -0.5f0,  0.5f0,  0.5f0,     0.0f0, 1.0f0, # Left  top
        -0.5f0, -0.5f0,  0.5f0,     0.0f0, 0.0f0, # Left  bottom
    ]

    vao = Ref{GLuint}()
    glGenVertexArrays(1, vao)

    glBindVertexArray(vao[])

    vbo = Ref{GLuint}()
    glGenBuffers(1, vbo)

    elementspervertex = 5

    glBindBuffer(GL_ARRAY_BUFFER, vbo[])
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_DYNAMIC_DRAW)

    glVertexAttribPointer(0, 3, GL_FLOAT, GL_FALSE, elementspervertex*sizeof(GLfloat), C_NULL)
    glEnableVertexAttribArray(0)

    glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, elementspervertex*sizeof(GLfloat), Ptr{Cvoid}(3 * sizeof(GLfloat)))
    glEnableVertexAttribArray(1)

    Mesh(vao[], length(vertices) / elementspervertex)
end

#
# Shader sources
#

vertexsource = """
#version 330 core

layout (location = 0) in vec3 aPos;
layout (location = 1) in vec2 aTextureCoordinate;

out vec2 TexCoord;

uniform mat4 model;
uniform mat4 view;
uniform mat4 projection;

void main()
{
    vec4 p = vec4(aPos.x, aPos.y, aPos.z, 1.0);
    gl_Position = projection * view * model * p;
    TexCoord = aTextureCoordinate;
}
"""

fragmentsource = """
#version 330 core

in vec2 TexCoord;
out vec4 FragColor;

uniform sampler2D mytexture;

void main()
{
    FragColor = texture(mytexture, TexCoord);
}
"""

#
# Shaders
#

struct ShaderError <: Exception
    msg::String
end

function createshader(shadersource, shadertype)
    shader = glCreateShader(shadertype)

    glShaderSource(shader, 1, Ptr{GLchar}[pointer(shadersource)], C_NULL)
    glCompileShader(shader)

    issuccess = Ref{GLint}()
    glGetShaderiv(shader, GL_COMPILE_STATUS, issuccess)
    if issuccess[] != GL_TRUE
        maxlength = 512
        actuallength = Ref{GLsizei}()
        infolog = Vector{GLchar}(undef, maxlength)
        glGetShaderInfoLog(shader, maxlength, actuallength, infolog)
        infomessage = String(infolog[1:actuallength[]])
        errormsg = "Shader failed to compile: $(infomessage)"
        throw(ShaderError(errormsg))
    end

    shader
end

function makeprogram()
    programid = glCreateProgram()
    vertexshader = createshader(vertexsource, GL_VERTEX_SHADER)
    fragmentshader = createshader(fragmentsource, GL_FRAGMENT_SHADER)

    glAttachShader(programid, vertexshader)
    glAttachShader(programid, fragmentshader)

    glLinkProgram(programid)

    issuccess = Ref{GLint}()
    glGetProgramiv(programid, GL_LINK_STATUS, issuccess)
    if issuccess[] != GL_TRUE
        throw(ShaderError("Shaders failed to link"))
    end

    programid
end

uniformlocation(program::GLuint, name::String) = glGetUniformLocation(program, Ptr{GLchar}(pointer(name)))

function uniform(program::GLuint, name::String, value::Matrix{GLfloat})
    location = uniformlocation(program, name)
    array = Ref([value...], 1)
    glUniformMatrix4fv(location, 1, GL_FALSE, array)
end

#
# Camera
#

const Vector3{T} = NTuple{3, T}

struct Camera
    fov::Float32
    windowwidth::Int
    windowheight::Int
    near::Float32
    far::Float32
end

function Camera(width, height) :: Camera
    fov = 0.25f0*pi
    near = 0.1f0
    far = 100.0f0
    Camera(
        fov,
        width,
        height,
        near,
        far
    )
end

#
# Perspective and transformations
#

function objectmodel()
    Matrix{GLfloat}([
        1f0 0f0 0f0 0f0;
        0f0 1f0 0f0 0f0;
        0f0 0f0 1f0 0f0;
        0f0 0f0 0f0 1f0;

    ])
end

function lookat() :: Matrix{Float32}
    Matrix{GLfloat}([
        1f0 0f0  0f0  0f0;
        0f0 1f0  0f0  0f0;
        0f0 0f0 -1f0 -3f0;
        0f0 0f0  0f0  1f0;
    ])
end

function perspective(camera) :: Matrix{GLfloat}
    tanhalf = tan(camera.fov/2f0)
    aspect = Float32(camera.windowwidth) / Float32(camera.windowheight)
    far = camera.far
    near = camera.near

    Matrix{GLfloat}(GLfloat[
        1f0/(aspect*tanhalf) 0f0           0f0                          0f0;
        0f0                  1f0/(tanhalf) 0f0                          0f0;
        0f0                  0f0           -(far + near) / (far - near) -2f0*far*near / (far - near);
        0.0f0                0f0           -1f0 0f0;
    ])
end

#
# Generate a 2D texture
# The size needs to be a multiple of two at each dimension.
# Making it a square 64x64 pixel texture.
#

function generatetexture(width, height)
    texturedata = UInt8[]
    for x = 1:width
        for y = 1:height
            r = UInt8(0)
            g = round(UInt8, 127 * sin(2.0 * pi * x / Float32(width)) + 127)
            b = round(UInt8, 127 * sin(2.0 * pi * y / Float32(height)) + 127)
            a = UInt8(255)

            push!(texturedata, r)
            push!(texturedata, g)
            push!(texturedata, b)
            push!(texturedata, a)
        end
    end

    texturedata
end

function maketexture()
    textureRef = Ref{GLuint}()
    glGenTextures(1, textureRef)
    textureid = textureRef[]

    glBindTexture(GL_TEXTURE_2D, textureid)

    width = 64
    height = 64
    data = generatetexture(width, height)

    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, data)
    glGenerateMipmap(GL_TEXTURE_2D)

    textureid
end

#
# Main loop
#

function render(mesh::Mesh, textureid::GLuint)
    glBindTexture(GL_TEXTURE_2D, textureid)
    glBindVertexArray(mesh.vao)
    glDrawArrays(GL_TRIANGLES, 0, mesh.numberofvertices)
end

function run()
    camera = Camera(1024, 800)

    # Create a window and its OpenGL context
    window = GLFW.CreateWindow(camera.windowwidth, camera.windowheight, "Julia 2D texture example")

    # Make the window's context current
    GLFW.MakeContextCurrent(window)

    glEnable(GL_CULL_FACE)
    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
    glEnable(GL_DEPTH_TEST)

    mesh = makequad()
    programid = makeprogram()
    textureid = maketexture()

    # Loop until the user closes the window
    while !GLFW.WindowShouldClose(window)
        glClearColor(0.2f0, 0.3f0, 0.3f0, 1.0f0)
        glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)

        # Set uniforms
        view = lookat()
        projection = perspective(camera)
        model = objectmodel()
        uniform(programid, "model", model)
        uniform(programid, "view", view)
        uniform(programid, "projection", projection)

        # Render here
        glUseProgram(programid)
        render(mesh, textureid)

        # Swap front and back buffers
        GLFW.SwapBuffers(window)

        # Poll for and process events
        GLFW.PollEvents()
    end

    GLFW.DestroyWindow(window)
end

run()