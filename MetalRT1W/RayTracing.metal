//
//  RayTracing.metal
//  MetalRT1W
//
//  Created by Ye Kuang on 2020/04/14.
//  Copyright © 2020 zkk. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

using ElemPtr = device const uchar*;

/// Basic data manipulation helpers

template <typename T>
T read(ElemPtr ptr) {
    return *reinterpret_cast<device const T*>(ptr);
}

template <typename T>
ElemPtr skip(ElemPtr ptr) {
    return ptr + sizeof(T);
}

template <typename T>
ElemPtr read_and_skip(ElemPtr ptr, thread T* data) {
    *data = read<T>(ptr);
    return skip<T>(ptr);
}

inline ElemPtr read_elem_bytes_and_skip(ElemPtr ptr, thread int32_t* bytes) {
    return read_and_skip<int32_t>(ptr, bytes);
}

inline ElemPtr skip_kind(ElemPtr elem) {
    return skip<int32_t>(elem);
}

/// Random

struct RandState {
    RandState(uint32_t s, float x, float y);
    uint32_t seed;
};

uint32_t rand_u32(thread RandState* rs) {
    // https://en.wikipedia.org/wiki/Linear_congruential_generator#Parameters_in_common_use
    uint32_t nxt = rs->seed * 1103515245 + 12345;
    rs->seed = nxt;
    return nxt * 1000000007;
}

float rand_f32(thread RandState* rs) {
    return rand_u32(rs) * (1.0f / 4294967296.0f);
}

RandState::RandState(uint32_t s, float x, float y) : seed(s) {
    seed *= *(thread uint32_t*)(&x);
    rand_u32(this);
    seed *= *(thread uint32_t*)(&y);
    rand_u32(this);
}

void init_rand_seed(thread RandState* rs, float x, float y) {
    rs->seed *= *(thread uint32_t*)(&x);
    rand_u32(rs);
    rs->seed *= *(thread uint32_t*)(&y);
    rand_u32(rs);
}

float3 random_in_unit_sphere(thread RandState* rs) {
    float3 p(0.0);
    do {
        p = 2.0 * float3(rand_f32(rs), rand_f32(rs), rand_f32(rs)) - float3(1.0);
    } while (dot(p, p) >= 1.0);
    return p;
}

/// Geometry

enum class GeometryKinds {
    group = 1,
    sphere = 2,
};

inline GeometryKinds read_geometry_kind(ElemPtr elem) {
    return static_cast<GeometryKinds>(read<int32_t>(elem));
}

class GeometryGroup {
public:
    explicit GeometryGroup(ElemPtr p) : ptr_(skip_kind(p)) {}
    
    inline int32_t count() const {
        return read<int32_t>(ptr_);
    }
    
    inline ElemPtr elems_begin() const {
        // offset = count
        return ptr_ + sizeof(int32_t);
    }
private:
    ElemPtr ptr_;
};

class Sphere {
public:
    explicit Sphere(ElemPtr p) : ptr_(skip_kind(p)) {}
    
    inline float3 center() const {
        return read<float3>(ptr_);
    }
    
    inline float radius() const {
        // offset = center
        return read<float>(ptr_ + sizeof(float3));
    }
    
    inline ElemPtr material_ptr() const {
        // offset = center + radius
        return (ptr_ + sizeof(float3) + sizeof(float));
    }
private:
    ElemPtr ptr_;
};

/// Ray

class Ray {
public:
    Ray(float3 o, float3 d) : origin_(o), dir_(normalize(d)) {}
    Ray() : Ray(float3(0.0), float3(1.0)) {}
    
    inline float3 origin() const { return origin_; }
    inline float3 direction() const { return dir_; }
    inline float3 point_at(float t) const {
        return origin_ + t * dir_;
    }
private:
    float3 origin_;
    float3 dir_;
};

struct HitRecord {
    float t;
    float3 point;
    float3 normal;
    ElemPtr material_ptr;
};

/// Material

enum class MaterialKinds {
    lambertian = 1,
    mmetal = 2,
    dielectrics = 3,
};

inline MaterialKinds read_material_kind(ElemPtr elem) {
    return static_cast<MaterialKinds>(read<int32_t>(elem));
}

inline float3 get_scattered_ray_origin(float3 point, float3 normal) {
    // Move |kEps| so that the scattered ray won't be self intersecting.
    constexpr float kEps = 5e-4;
    return point + normal * kEps;
}

class Lambertian {
public:
    explicit Lambertian(ElemPtr p) : ptr_(skip_kind(p)) {}
    
    inline float3 albedo() const {
        return read<float3>(ptr_);
    }
    
    bool scatter(thread const Ray& r_in, thread const HitRecord& rec, thread RandState* rand_state, thread float3* attenuation, thread Ray* r_scattered) const {
        *attenuation = albedo();
        const float3 new_dir = rec.normal + random_in_unit_sphere(rand_state);
        *r_scattered = Ray(get_scattered_ray_origin(rec.point, rec.normal), new_dir);
        return true;
    }
private:
    ElemPtr ptr_;
};

class MMetal {
public:
    explicit MMetal(ElemPtr p) : ptr_(skip_kind(p)) {}
    
    inline float3 albedo() const {
        return read<float3>(ptr_);
    }
    
    inline float fuzz() const {
        // offset = albedo
        return read<float>(ptr_ + sizeof(float3));
    }
    
    bool scatter(thread const Ray& r_in, thread const HitRecord& rec, thread RandState* rand_state, thread float3* attenuation, thread Ray* r_scattered) const {
        const float3 reflected = reflect(r_in.direction(), rec.normal);
        if (dot(reflected, rec.normal) <= 0) {
            return false;
        }
        *attenuation = albedo();
        *r_scattered = Ray(get_scattered_ray_origin(rec.point, rec.normal), reflected + fuzz() * random_in_unit_sphere(rand_state));
        return true;
    }
private:
    ElemPtr ptr_;
};

float schlick(float cosine, float refract_index) {
    float r0 = (1.0 - refract_index) / (1.0 + refract_index);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * pow((1.0 - cosine), 5);
}

class Dielectrics {
public:
    explicit Dielectrics(ElemPtr p) : ptr_(skip_kind(p)) {}
    
    inline float refract_index() const {
        return read<float>(ptr_);
    }
    
    inline float fuzz() const {
        // offset = refract_index
        return read<float>(ptr_ + sizeof(float));
    }
    
    bool scatter(thread const Ray& r_in, thread const HitRecord& rec, thread RandState* rand_state, thread float3* attenuation, thread Ray* r_scattered) const {
        const float rfi = refract_index();
        float ni_over_nt = 0.0;
        float3 outward_normal(0.0);
        float cosine = dot(r_in.direction(), rec.normal);
        if (cosine > 0) {
            outward_normal = -rec.normal;
            ni_over_nt = rfi;
            cosine = rfi * cosine;
        } else {
            outward_normal = rec.normal;
            ni_over_nt = 1.0 / rfi;
            cosine = -cosine;
        }
        
        const float3 refracted = refract(r_in.direction(), outward_normal, ni_over_nt);
        const float reflect_prob = (length(refracted) > 0.5) ? schlick(cosine, rfi) : 1.0;
        const float3 fuzzed_dir = fuzz() * random_in_unit_sphere(rand_state);
        if (rand_f32(rand_state) < reflect_prob) {
            *r_scattered = Ray(get_scattered_ray_origin(rec.point, outward_normal), reflect(r_in.direction(), rec.normal) + fuzzed_dir);
        } else {
            // negate |outward_normal| because for refraction, we need to move the point to the other
            // side of the boundary.
            *r_scattered = Ray(get_scattered_ray_origin(rec.point, -outward_normal), refracted + fuzzed_dir);
        }
        
        *attenuation = float3(1.0);
        return true;
    }
    
private:
    ElemPtr ptr_;
};

bool scatter(ElemPtr elem, thread const Ray& r_in, thread const HitRecord& rec, thread RandState* rand_state, thread float3* attenuation, thread Ray* r_scattered) {
    int32_t bytes_unused;
    elem = read_elem_bytes_and_skip(elem, &bytes_unused);
    
    const auto kind = read_material_kind(elem);
    if (kind == MaterialKinds::lambertian) {
        Lambertian l(elem);
        return l.scatter(r_in, rec, rand_state, attenuation, r_scattered);
    } else if (kind == MaterialKinds::mmetal) {
        MMetal m(elem);
        return m.scatter(r_in, rec, rand_state, attenuation, r_scattered);
    } else if (kind == MaterialKinds::dielectrics) {
        Dielectrics d(elem);
        return d.scatter(r_in, rec, rand_state, attenuation, r_scattered);
    }
    return false;
}

/// Ray - Geomtry Hit

struct RecursionRecord {
    ElemPtr nxt_elem;
    int32_t nxt;
    int32_t end;
};

bool hit(Sphere sphere, thread const Ray& r, float t_min, float t_max, thread HitRecord* rec) {
    const float3 center = sphere.center();
    const float radius = sphere.radius();
    const float3 oc = r.origin() - center;
    const float3 rdir = r.direction();
    const float a = dot(rdir, rdir);
    const float b = 2.0 * dot(oc, rdir);
    const float c = dot(oc, oc) - radius * radius;
    const float discriminant = b * b - 4 * a * c;
    if (discriminant < 0) {
        return false;
    }
    
    const float discr_sqrt = sqrt(discriminant);
    float root = ((-b - discr_sqrt) / a) * 0.5;
    if (!(t_min < root && root < t_max)) {
        root = ((-b + discr_sqrt) / a) * 0.5;
    }
    if (!(t_min < root && root < t_max)) {
        return false;
    }
    rec->t = root;
    rec->point = r.point_at(rec->t);
    rec->normal = normalize(rec->point - center);
    rec->material_ptr = sphere.material_ptr();
    return true;
}

bool hit_base(ElemPtr elem, thread const Ray& r, float t_min, float t_max, thread HitRecord* rec) {
    const auto kind = read_geometry_kind(elem);
    if (kind == GeometryKinds::sphere) {
        return hit(Sphere(elem), r, t_min, t_max, rec);
    }
    // assert false
    return false;
}

bool hit(GeometryGroup group, thread const Ray& r, float t_min, float t_max, thread HitRecord* rec) {
    bool hit_any = false;
    
    RecursionRecord stack[4];
    stack[0] = {group.elems_begin(), 0, group.count()};
    int8_t top = 0;
    while (top >= 0) {
        auto record = stack[top];
        ElemPtr elem = record.nxt_elem;
        bool pop_stack = true;
        for (int i = record.nxt; i < record.end; ++i) {
            int32_t bytes;
            elem = read_elem_bytes_and_skip(elem, &bytes);
            const auto kind = read_geometry_kind(elem);
            if (kind == GeometryKinds::group) {
                stack[top].nxt_elem = elem + bytes;
                stack[top].nxt = i + 1;
                ++top;
                pop_stack = false;
                
                GeometryGroup subg(elem);
                stack[top] = {subg.elems_begin(), 0, subg.count()};
                break;
            } else if (hit_base(elem, r, t_min, t_max, rec)) {
                hit_any = true;
                t_max = rec->t;
            }
            elem += bytes;
            if (pop_stack) {
                --top;
            }
        }
    }
    return hit_any;
}

bool hit(ElemPtr elem, thread const Ray& r, float t_min, float t_max, thread HitRecord* rec) {
    // bytes is already skipped
    const auto kind = read_geometry_kind(elem);
    if (kind == GeometryKinds::group) {
        return hit(GeometryGroup(elem), r, t_min, t_max, rec);
    } else {
        return hit_base(elem, r, t_min, t_max, rec);
    }
    
    return false;
}

struct RayTracingParams {
    float3 camera_pos;
    float aperture;
    float focus_dist;
    float2 screen_size;
    int32_t sample_batch_size;
    int32_t cur_batch_idx;
    int32_t max_depth;
};

float3 random_in_unit_disk(thread RandState* rand_state) {
    float3 p(0.0);
    do {
        p = 2.0 * float3(rand_f32(rand_state), rand_f32(rand_state), 0.0) - float3(1.0, 1.0, 0.0);
    } while (dot(p, p) >= 1.0);
    return p;
}

class VanillaCamera {
public:
    VanillaCamera(device const RayTracingParams* params) :
    width_(params->screen_size.x),
    height_(params->screen_size.y),
    origin_(params->camera_pos),
    lens_radius_(params->aperture * 0.5),
    focus_dist_(params->focus_dist) {}
    
    Ray get_ray(float x, float y, thread RandState* rand_state) const {
        const float3 o = origin_ + lens_radius_ * random_in_unit_disk(rand_state);
        const float3 target(x * width_ + rand_f32(rand_state),
                            y * height_ + rand_f32(rand_state),
                            origin_.z + focus_dist_);
        return Ray(o, target - o);
    }
private:
    float width_;
    float height_;
    float3 origin_;
    float lens_radius_;
    float focus_dist_;
};

constant constexpr float kTMax = 1e6;

float3 ray_trace(Ray ray, ElemPtr elem, int32_t max_depth, thread RandState* rand_state) {
    int32_t bytes_unused;
    elem = read_elem_bytes_and_skip(elem, &bytes_unused);
    
    int8_t depth = 0;
    float3 color(1.0);
    while (true) {
        HitRecord rec;
        if (hit(elem, ray, 0.0, kTMax, &rec)) {
            float3 attenuation;
            Ray ray_new;
            const bool scattered = scatter(rec.material_ptr, ray, rec, rand_state, &attenuation, &ray_new);
            if (!((depth < max_depth) && scattered)) {
                return float3(0.0);
            }
            ++depth;
            color *= attenuation;
            ray = ray_new;
        } else {
            const float t = 0.5 * (ray.direction().y + 1.0);
            // gradient blue
            color *= ((1.0 - t) * float3(1.0) + t * float3(0.5, 0.7, 1.0));
            break;
        }
    }
    return color;
}

struct ForwardPosTexVertexOut {
    float4 position [[position]];
    float2 tex_coord;
};

vertex ForwardPosTexVertexOut forward_vert(device const float4* data [[buffer(0)]],
                                           uint vid [[vertex_id]]) {
    ForwardPosTexVertexOut result;
    const float4 d = data[vid];
    result.position = float4(d.x, d.y, 0.0, 1.0);
    result.tex_coord = d.zw;
    return result;
}

//#define ORTHOGONAL_PROJECTION

fragment float4 ray_trace_frag(ElemPtr geometry [[buffer(0)]],
                               device RayTracingParams* params [[buffer(1)]],
                               device const uint32_t* rand_seed [[buffer(2)]],
                               texture2d<float> color_tex [[texture(0)]],
                               ForwardPosTexVertexOut frag_data [[ stage_in ]]) {
    const float2 tex_coord = frag_data.tex_coord;
    const float tx = tex_coord.x;
    const float ty = 1.0 - tex_coord.y;
    RandState rand_state(*rand_seed, tx, ty);
    
    VanillaCamera camera(params);
    const auto sample_batch_size = params->sample_batch_size;
    float3 color(0.0);
    for (int i = 0; i < sample_batch_size; ++i) {
#ifdef ORTHOGONAL_PROJECTION
        const float2 screen_size = params->screen_size;
        const float3 target_pos(tx * screen_size.x + rand_f32(&rand_state),
                                ty * screen_size.y + rand_f32(&rand_state),
                                0.0);
        Ray r(target_pos, float3(0.0, 0.0, 1.0));
#else
        Ray r = camera.get_ray(tx, ty, &rand_state);
#endif
        color += ray_trace(r, geometry, params->max_depth, &rand_state);
    }
    color = sqrt(color / sample_batch_size);
    
    const int cur_iter = params->cur_batch_idx;
    constexpr sampler s(mag_filter::linear, min_filter::linear, address::clamp_to_zero);
    const float3 prev_color = color_tex.sample(s, tex_coord).xyz;
    const float4 result((prev_color * cur_iter + color) / (cur_iter + 1.0), 1.0);
    return result;
}

///
/// Functions and kernels below are mostly for debugging
///
float3 sphere_normal(Ray r, ElemPtr elem) {
    int32_t bytes_unused;
    elem = read_elem_bytes_and_skip(elem, &bytes_unused);
    
    HitRecord rec;
    if (hit(Sphere(elem), r, 0, kTMax, &rec)) {
        return 0.5 * rec.normal + 0.5;
    }
    const float t = 0.5 * (r.direction().y + 1.0);
    // gradient blue
    return ((1.0 - t) * float3(1.0) + t * float3(0.5, 0.7, 1.0));
}

device float* flatten(Sphere sphere, device float* out) {
    const float3 center = sphere.center();
    *out = 42;
    ++out;
    out[0] = center[0];
    out[1] = center[1];
    out[2] = center[2];
    out[3] = sphere.radius();
    return out + 4;
}

device float* flatten_base(ElemPtr elem, device float* out) {
    const auto kind = read_geometry_kind(elem);
    if (kind == GeometryKinds::sphere) {
        return flatten(Sphere(elem), out);
    }
    return out;
}

device float* flatten(GeometryGroup group, device float* out) {
    out[0] = 41;
    out[1] = group.count();
    out += 2;
    
    RecursionRecord stack[4];
    int8_t stack_top = 0;
    stack[stack_top] = {group.elems_begin(), 0, group.count()};
    while (stack_top >= 0) {
        auto record = stack[stack_top];
        ElemPtr elem = record.nxt_elem;
        bool pop_stack = true;
        for (int i = record.nxt; i < record.end; ++i) {
            int32_t bytes;
            elem = read_elem_bytes_and_skip(elem, &bytes);
            const auto kind = read_geometry_kind(elem);
            if (kind == GeometryKinds::group) {
                stack[stack_top].nxt_elem = (elem + bytes);
                stack[stack_top].nxt = i + 1;
                ++stack_top;
                
                pop_stack = false;
                GeometryGroup g(elem);
                stack[stack_top] = {g.elems_begin(), 0, g.count()};
                out[0] = 41;
                out[1] = g.count();
                out += 2;
                break;
            } else {
                out = flatten_base(elem, out);
                elem += bytes;
            }
        }
        if (pop_stack) {
            --stack_top;
        }
    }
    return out;
}

kernel void flatten_kernel(ElemPtr data [[buffer(0)]],
                           device float* out) {
    int32_t b;
    data = read_elem_bytes_and_skip(data, &b);
    
    const auto kind = read_geometry_kind(data);
    if (kind == GeometryKinds::group) {
        flatten(GeometryGroup(data), out);
    } else {
        flatten_base(data, out);
    }
}
