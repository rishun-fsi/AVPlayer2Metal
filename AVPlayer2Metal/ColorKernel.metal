//
//  ColorKernel.metal
//  AVPlayer2Metal
//
//  Created by lisyunn on 2020/12/05.
//

#include <metal_stdlib>
using namespace metal;
 
kernel void colorKernel(texture2d<float, access::read> inTexture [[ texture(0) ]],
                        texture2d<float, access::write> outTexture [[ texture(1) ]],
                        device const float *time [[ buffer(0) ]],
                        uint2 gid [[ thread_position_in_grid ]])
{
    const float4 colorAtPixel = inTexture.read(gid);
    outTexture.write(colorAtPixel, gid);
}


