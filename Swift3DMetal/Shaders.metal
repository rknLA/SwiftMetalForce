//
//  Shaders.metal
//  Swift3DMetal
//
//  Created by Kevin Nelson on 14/09/16.
//  Copyright © 2016 rknLA. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

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
                             //constant Uniforms &uniforms [[buffer(1)]],
                             unsigned int vid [[vertex_id]])
{
    VertexOut out;
    out.position = vertices[vid].position;
    out.color = half4(vertices[vid].color);
    return out;
}

fragment half4 fragment_func(VertexOut vert [[stage_in]])
{
    return vert.color;
}
