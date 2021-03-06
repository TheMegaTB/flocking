/// Copyright (c) 2019 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

#include <metal_stdlib>
#include "Structs.metal"
using namespace metal;

struct InteractionVertexOut {
    float4 position [[position]];
    float size [[point_size]];
};

vertex InteractionVertexOut interaction_vertex(const device InteractionNode* interaction_array [[ buffer(0) ]], const device float4x4 &world_model_matrix [[ buffer(1) ]], const device float4x4 &projection_matrix [[ buffer(2) ]], unsigned int vid [[ vertex_id ]]) {
    InteractionVertexOut out;

    out.position = projection_matrix * world_model_matrix * float4(interaction_array[vid].position.xyz, 1.0);
    out.size = interaction_array[vid].repulsionStrength + 50;

    return out;
}

fragment half4 interaction_fragment(InteractionVertexOut in [[stage_in]]) {
    return half4(1.0, 0, 0, 1.0);
}
