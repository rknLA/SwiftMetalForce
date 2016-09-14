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
} VertexOut;

vertex VertexOut vertex_func(device VertexIn *vertices [[buffer(0)]],
                             constant Uniforms &uniforms [[buffer(1)]],
                             unsigned int vid [[vertex_id]])
{
    VertexOut out;
    out.position = vertices[vid].position;

    float zpos = out.position[2];

    float4 position2d = float4(out.position[0], out.position[1], 0, 0);
    float4 touches[] = {uniforms.touch1, uniforms.touch2, uniforms.touch3, uniforms.touch4, uniforms.touch5};

    float relevanceRange = uniforms.relevanceRange[0];

    int i = 0;
    for (i = 0; i < 5; ++i) {
        float touchX = touches[i][0];
        float touchY = touches[i][1];

        float4 touchPos2d = float4(touchX, touchY, 0, 0);

        float dist = distance(position2d, touchPos2d);
        if (dist < relevanceRange) {
            zpos -= (touches[i][2] * (1 - dist / relevanceRange));
        }
    }

    out.position[2] = zpos;

    out.color = half4(vertices[vid].color);
    return out;
}

fragment half4 fragment_func(VertexOut vert [[stage_in]])
{
    return vert.color;
}
