@vs vs
in vec2 v_i_pos;
in vec2 v_i_uv;
in vec4 v_i_col;

out vec4 v_o_col;
out vec2 v_o_uv;

void main() {
    gl_Position = vec4(v_i_pos, 0, 1);
    v_o_col = v_i_col;  
    v_o_uv = v_i_uv;
}
@end

@fs fs
in vec4 v_o_col;
in vec2 v_o_uv;

layout(binding=0) uniform texture2D tex;
layout(binding=0) uniform sampler samp;

out vec4 f_o_col;

void main() {
    f_o_col = texture(sampler2D(tex, samp), v_o_uv) * v_o_col;
}
@end

@program main vs fs
