//
//  Shaders.metal
//  Swift3DMetal
//
//  Created by Kevin Nelson on 14/09/16.
//  Copyright © 2016 rknLA. All rights reserved.
//

#include <metal_stdlib>
#include <metal_geometric>
using namespace metal;

#define M_PI  3.14159265358979323846264338327950288

constant float kPi   = float(M_PI);
constant float k2Pi3 = 2.0 * kPi/3.0;
constant float k4Pi3 = 4.0 * kPi/3.0;

typedef struct
{
    float4 touch1;
    float4 touch2;
    float4 touch3;
    float4 touch4;
    float4 touch5;
    float4 relevanceRange;
} Uniforms;

typedef struct
{
    float4 position;
    float4 color;
} VertexIn;

typedef struct {
    float4 position [[position]];
    half4 color;
    float dist;
} VertexOut;

vertex VertexOut vertex_func(device VertexIn *vertices [[buffer(0)]],
                             constant Uniforms &uniforms [[buffer(1)]],
                             unsigned int vid [[vertex_id]])
{
    VertexOut out;
    out.position = vertices[vid].position;

    float zpos = 1.0;

    float4 position2d = float4(out.position[0], out.position[1], 0, 0);
    float4 touches[] = {uniforms.touch1, uniforms.touch2, uniforms.touch3, uniforms.touch4, uniforms.touch5};

    float relevanceRange = uniforms.relevanceRange[0];

    float out_dist = 0.0;

    int i = 0;
    for (i = 0; i < 5; ++i) {
        float touchX = touches[i][0];
        float touchY = touches[i][1];

        float4 touchPos2d = float4(touchX, touchY, 0, 0);

        float dist = distance(position2d, touchPos2d);
        float normalized_distance = dist / relevanceRange;
        if (dist < relevanceRange) {
            zpos -= (touches[i][2] * (1 - normalized_distance));
        }
        out_dist = max(out_dist, dist / relevanceRange);
    }

    out.position[2] = zpos;
    out.dist = out_dist;

    //out.color = half4(vertices[vid].color);
    out.color = half4(0.2, 0.2, 0.2, 1.0);
    return out;
}

fragment half4 fragment_func(VertexOut vert [[stage_in]])
{

    half3 color = 0.0;

    if (vert.position[2] != 1.0) {
        color.r = cos(kPi * vert.position[2] * vert.position[2] * vert.position[2] * vert.position[1]);
        color.g = sin(1.1 * kPi * vert.position[2] + k2Pi3 / vert.position[2]);
        color.b = sin(3.3 * kPi * vert.position[2] * vert.position[0]);
    }

    return half4(color.r, color.g, color.b, 1.0);
}
