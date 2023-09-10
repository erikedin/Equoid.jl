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

using Alfar.Visualizer
using Alfar.Visualizer.ShowTextures.Exports
using Alfar.Rendering.Textures

context = Ref{Visualizer.VisualizerContext}()

context[] = Visualizer.start()

ev = Visualizer.SelectVisualizationEvent("ShowTexture")
put!(context[].channel, ev)


#for value = 0.0f0:0.1f0:0.8f0
#    ev = Exports.semitransparent(value)
#    put!(context[].channel, ev)
#
#    sleep(2)
#end

slicepath = if length(ARGS) > 0
    ARGS[1]
else
    "CThead.90"
end

textureinput = open(slicepath, "r") do io
    flatformat = FlatBinaryFormat{UInt16}(io)
    dimension = TextureDimension{2}(256, 256)
    IntensityTextureInput{2, UInt16}(dimension, flatformat)
end

if !isinteractive()
    Visualizer.waituntilstop(context[])
end