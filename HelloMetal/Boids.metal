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

uint boid_id(uint2 gid, uint2 grid_dimensions) {
    return gid.y * grid_dimensions.x + gid.x;
}

float3 rotate(float3 vector, float byAngle) {
    return float3(
        vector.x * cos(byAngle) - vector.y * sin(byAngle),
        vector.x * sin(byAngle) + vector.y * cos(byAngle),
        vector.z
    );
}

float angle(float3 ofVector) {
    return atan2(ofVector.y, ofVector.x);
}

float falloff(float dist, float maximumDistance) {
    float distancePercentage = dist / maximumDistance;
    return (1 - sqrt(distancePercentage)) * 2;
}

bool vector_is_not_null(float3 vector) {
    return vector.x != 0 || vector.y != 0 || vector.z != 0;
}

__constant float width = 2.0;
__constant float height = 2.0;
__constant float depth = 2.0;

__constant float scale = 0.91 / 1024.0;
__constant float friendRadius = 60.0 * scale;
__constant float crowdRadius = friendRadius / 1.3;
__constant float avoidRadius = 90.0 * scale;
__constant float cohesionRadius = friendRadius * 5;

kernel void boid_flocking(
        device Boid* boid_array [[ buffer(0) ]],
        const device uint* boid_count [[ buffer(1) ]],

        device InteractionNode* interaction_array [[ buffer(2) ]],
        const device uint* interaction_count [[ buffer(3) ]],

        constant GlobalSettings &global_settings [[ buffer(4) ]],
        constant TeamSettings* team_settings_array [[ buffer(5) ]],

        uint2 gid [[thread_position_in_grid]],
        uint2 grid_dimensions [[threads_per_grid]])
{
    uint id = boid_id(gid, grid_dimensions);
    if (id >= *boid_count) return;

    TeamSettings team_settings = team_settings_array[boid_array[id].teamID];

    float maxVelocity = boid_array[id].maxVelocity * scale;

    bool doWrap = global_settings.wrapEnabled;
    bool considerTeams = global_settings.teamsEnabled;

    // Step 1: Wrap around at the screen edges
    if (doWrap) {
        while (boid_array[id].position.x > width / 2) {
            boid_array[id].position.x -= width;
        }

        while (boid_array[id].position.x < -(width / 2)) {
            boid_array[id].position.x += width;
        }

        while (boid_array[id].position.y > height / 2) {
            boid_array[id].position.y -= height;
        }

        while (boid_array[id].position.y < -(height / 2)) {
            boid_array[id].position.y += height;
        }

        while (boid_array[id].position.z > depth / 2) {
            boid_array[id].position.z -= depth;
        }

        while (boid_array[id].position.z < -(depth / 2)) {
            boid_array[id].position.z += depth;
        }
    } else if (!doWrap) {
        if (boid_array[id].position.x > width / 2) {
            boid_array[id].position.x = width / 2;
            boid_array[id].velocity.x *= -1.0;
        } else if (boid_array[id].position.x < -(width / 2)) {
            boid_array[id].position.x = -(width / 2);
            boid_array[id].velocity.x *= -1.0;
        } else if (boid_array[id].position.y > height / 2) {
            boid_array[id].position.y = height / 2;
            boid_array[id].velocity.y *= -1.0;
        } else if (boid_array[id].position.y < -(height / 2)) {
            boid_array[id].position.y = -(height / 2);
            boid_array[id].velocity.y *= -1.0;
        } else if (boid_array[id].position.z > depth / 2) {
            boid_array[id].position.z = depth / 2;
            boid_array[id].velocity.z *= -1.0;
        } else if (boid_array[id].position.z < -(depth / 2)) {
            boid_array[id].position.z = -(depth / 2);
            boid_array[id].velocity.z *= -1.0;
        }
    }

    // Step 2-5: Iterate over all neighbors
    float3 alignmentDirection = float3(0, 0, 0);
    float3 separationDirection = float3(0, 0, 0);
    float3 cohesionDirection = float3(0, 0, 0);
    float3 teamDirection = float3(0, 0, 0);

    uint alignmentCount = 0;
    uint separationCount = 0;
    uint cohesionCount = 0;
    uint teamCount = 0;

    for (uint i = 0; i < *boid_count; i++) {
        float3 directionVector = boid_array[id].position - boid_array[i].position;
        float d = sqrt(directionVector.x*directionVector.x + directionVector.y*directionVector.y + directionVector.z*directionVector.z);

        if ((!considerTeams || boid_array[id].teamID == boid_array[i].teamID) && d > 0) {
            // Step 2: Calculate alignment
            if (d < friendRadius && length_squared(boid_array[i].velocity) > 0) {
                alignmentDirection += normalize(boid_array[i].velocity) * falloff(d, friendRadius);
                alignmentCount++;
            }

            // Step 3: Calculate separation
            if (d < crowdRadius && vector_is_not_null(directionVector)) {
                separationDirection += normalize(directionVector) * falloff(d, crowdRadius);
                separationCount++;
            }

            // Step 4: Calculate cohesion
            if (d < cohesionRadius) {
                cohesionDirection += boid_array[i].position;
                cohesionCount++;
            }
        } else if (d > 0) {
            // Step 3: Calculate team separation
            float radius = boid_array[id].teamID == 1 ? crowdRadius * 15 : crowdRadius * 2.5;
//            float radius = crowdRadius * 1.5;
            if (d < radius) {
                teamDirection += normalize(directionVector)  * falloff(d, radius);
                teamCount++;
            }
        }
    }

    // Step 5: Calculate repulsion/adhesion
    float3 repulsionDirection = float3(0, 0, 0);
    uint repulsionCount = 0;

    for (uint i = 0; i < *interaction_count; i++) {
        float d = abs(distance(boid_array[id].position, interaction_array[i].position));

        if (d > 0 && d < avoidRadius && vector_is_not_null(boid_array[id].velocity)) {
            float distanceMultiplier = falloff(d, avoidRadius) * 100;
            float intensity = length(boid_array[id].velocity);
            float3 direction = normalize(boid_array[id].position - interaction_array[i].position);

            repulsionDirection += direction * intensity * distanceMultiplier;
            repulsionCount++;
        }
    }

    // Step 6: Do post-processing on the values from Steps 2-5
    if (alignmentCount > 0) alignmentDirection /= alignmentCount;
    if (separationCount > 0) separationDirection /= separationCount;
    if (repulsionCount > 0) repulsionDirection /= repulsionCount;
    if (teamCount > 0) teamDirection /= teamCount;

    if (cohesionCount > 0) {
        cohesionDirection /= cohesionCount;
        cohesionDirection -= boid_array[id].position;
        cohesionDirection = normalize(cohesionDirection) * 0.05;
    }

    // Step 7: Calculate noise
    // TODO Previous implementations were kinda broken since the sum of all noise equals 0 thus the school as a whole didn't move

    // Step 8: Scale calculated values
    float calculationScale = scale;
    alignmentDirection *= calculationScale * team_settings.alignmentStrength; // * 0.3;
    separationDirection *= calculationScale * team_settings.separationStrength;
    cohesionDirection *= calculationScale * team_settings.cohesionStrength;
    repulsionDirection *= calculationScale * 35;
    teamDirection *= calculationScale * team_settings.teamStrength;

    // Interlude: Wait for all threads before mutating ourselves
    threadgroup_barrier(mem_flags::mem_device);

    // Step 9: Add values to velocity
    boid_array[id].velocity += alignmentDirection;
    boid_array[id].velocity += separationDirection;
    boid_array[id].velocity += cohesionDirection;
    boid_array[id].velocity += repulsionDirection;
    boid_array[id].velocity += teamDirection;

    // Step 10: Limit velocity
    float maximumVelocity = maxVelocity * team_settings.maximumSpeedMultiplier;
    if (vector_is_not_null(boid_array[id].velocity) && length(boid_array[id].velocity) > maximumVelocity * 1.5) {
        boid_array[id].velocity = normalize(boid_array[id].velocity) * maximumVelocity;
    }

    // Step 11: Apply velocity to position
    boid_array[id].position += boid_array[id].velocity * global_settings.simulationSpeed;
}

struct VertexIn {
    packed_float3 position;
    float speedPercentage;
    float heading;
    uint teamID;
};

float3x3 rotationMatrix(float3 direction) {
    if (!vector_is_not_null(direction)) return float3x3(1);

    float3 rotationZ = direction;
    float3 rotationX = normalize(cross(float3(0, 1, 0), rotationZ));
    float3 rotationY = normalize(cross(rotationZ, rotationX));
    return float3x3({ rotationX, rotationY, rotationZ });
}

kernel void boid_to_triangles(
      device VertexIn* vertex_array [[ buffer(0) ]],
      const device Boid* boid_array [[ buffer(1) ]],
      const device TeamSettings* team_settings_array [[ buffer(2) ]],
      const device uint* boid_count [[ buffer(3) ]],
      uint2 gid [[thread_position_in_grid]],
      uint2 grid_dimensions [[threads_per_grid]])
{
    uint index = boid_id(gid, grid_dimensions);
    if (index >= *boid_count) return;

    Boid b = boid_array[index];
    TeamSettings team_settings = team_settings_array[b.teamID];
    uint output_index = index * 3 * 4;
    float3 position = b.position;

    float size = 0.005 * team_settings.boidSize;

    float previousHeading = vertex_array[output_index].heading;
    float heading = vector_is_not_null(b.velocity) ?  angle(b.velocity) - M_PI_2_F : previousHeading;
    float speed = vector_is_not_null(b.velocity) ? length(b.velocity) : 0;
    uint team = b.teamID;

    float maximumSpeed = boid_array[index].maxVelocity * scale * team_settings.maximumSpeedMultiplier;
    float speedPercentage = speed / maximumSpeed;

    float3 normalizedVelocity = vector_is_not_null(b.velocity) ? normalize(b.velocity) : b.velocity;
    float3x3 lookAtMatrix = rotationMatrix(normalizedVelocity);

    float3 middle = lookAtMatrix * float3(0, 0, 2 * size);
    float3 top = lookAtMatrix * float3(size, 0, 0);
    float3 left = lookAtMatrix * float3(0.5 * size, -0.866 * size, 0);
    float3 right = lookAtMatrix * float3(0.5 * size, 0.866 * size, 0);

    vertex_array[output_index     ] = { top + position, speedPercentage, heading, team };
    vertex_array[output_index + 1 ] = { left + position, speedPercentage, heading, team };
    vertex_array[output_index + 2 ] = { right + position, speedPercentage, heading, team };

    vertex_array[output_index + 3 ] = { middle + position, 0.0, heading, team };
    vertex_array[output_index + 4 ] = { left + position, speedPercentage, heading, team };
    vertex_array[output_index + 5 ] = { right + position, speedPercentage, heading, team };

    vertex_array[output_index + 6 ] = { middle + position, 0.0, heading, team };
    vertex_array[output_index + 7 ] = { top + position, speedPercentage, heading, team };
    vertex_array[output_index + 8 ] = { right + position, speedPercentage, heading, team };

    vertex_array[output_index + 9 ] = { middle + position, 0.0, heading, team };
    vertex_array[output_index + 10] = { left + position, speedPercentage, heading, team };
    vertex_array[output_index + 11] = { top + position, speedPercentage, heading, team };
}


// MARK: - Boid render shaders

struct VertexOut {
    float4 position [[position]];
    float speedPercentage;
    uint teamID;
};

vertex VertexOut boid_vertex(const device VertexIn* vertex_array [[ buffer(0) ]], const device float4x4 &world_model_matrix [[ buffer(1) ]], const device float4x4 &projection_matrix [[ buffer(2) ]], unsigned int vid [[ vertex_id ]]) {
    VertexOut out;
    out.position = projection_matrix * world_model_matrix * float4(vertex_array[vid].position, 1);

    out.speedPercentage = vertex_array[vid].speedPercentage;
    out.teamID = vertex_array[vid].teamID;

    return out;
}

fragment half4 boid_fragment(VertexOut in [[stage_in]]) {
    half4 base_color = half4(0, 0, 0, 0);

    if (in.teamID == 0) {
        base_color = half4(0.0, 0.51, 0.56, 0.0);
    } else if (in.teamID == 1) {
        base_color = half4(0.9, 0.3, 0.1, 0.0);
    }

    float colorMix = (1 - pow(in.speedPercentage, 0.7)) * 0.5;
    half4 maximumColor = half4(1, 1, 1, 1);

    return half4(
        base_color.x + (maximumColor.x - base_color.x) * colorMix,
        base_color.y + (maximumColor.y - base_color.y) * colorMix,
        base_color.z + (maximumColor.z - base_color.z) * colorMix,
        base_color.w + (maximumColor.w - base_color.w) * colorMix
    );
}
