//! Fixed-size numerical kernels for the configured eight-joint rigid model.
//! No world, native physics engine, policy selection, or mutable global state.
use std::slice;
const P:usize=151;
const F:usize=186;
type V=[f64;3];
type M=[[f64;3];3];
fn add(a:V,b:V)->V {[a[0]+b[0],a[1]+b[1],a[2]+b[2]]}
fn sub(a:V,b:V)->V {[a[0]-b[0],a[1]-b[1],a[2]-b[2]]}
fn scale(a:V,s:f64)->V {[a[0]*s,a[1]*s,a[2]*s]}
fn cross(a:V,b:V)->V {[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]]}
fn vec(a:&[f64],i:usize)->V {[a[i],a[i+1],a[i+2]]}
fn put(a:&mut [f64],i:usize,v:V) {a[i..i+3].copy_from_slice(&v);}
fn mat(a:&[f64],i:usize)->M {[vec(a,i),vec(a,i+3),vec(a,i+6)]}
fn putmat(a:&mut [f64],i:usize,m:M) {for j in 0..3 {put(a,i+j*3,m[j]);}}
fn mv(m:M,v:V)->V {let mut a=[0.;3];for i in 0..3 {for j in 0..3 {a[i]+=m[i][j]*v[j];}}a}
fn mm(a:M,b:M)->M {let mut c=[[0.;3];3];for i in 0..3 {for j in 0..3 {for k in 0..3 {c[i][j]+=a[i][k]*b[k][j];}}}c}
fn proper(p:&[f64])->bool {
    p.len()==P && p.iter().all(|x|x.is_finite()) && p[..9].iter().all(|x|*x>0.)
        && (0..8).all(|j|p[63+j]>=0. && p[63+j]<=j as f64 && p[63+j].fract()==0.)
}
fn rotation(axis:V,angle:f64)->M {
    let [x,y,z]=axis;let k=[[0.,-z,y],[z,0.,-x],[-y,x,0.]];let kk=mm(k,k);
    let mut r=[[0.;3];3];let s=angle.sin();let c=1.-angle.cos();
    for i in 0..3 {for j in 0..3 {r[i][j]=(if i==j {1.}else{0.})+s*k[i][j]+c*kk[i][j];}}r
}
fn quaternion(q:&[f64])->M {
    let n=q.iter().map(|x|x*x).sum::<f64>().sqrt();let (x,y,z,w)=(q[0]/n,q[1]/n,q[2]/n,q[3]/n);
    [[1.-2.*(y*y+z*z),2.*(x*y-z*w),2.*(x*z+y*w)],
     [2.*(x*y+z*w),1.-2.*(x*x+z*z),2.*(y*z-x*w)],
     [2.*(x*z-y*w),2.*(y*z+x*w),1.-2.*(x*x+y*y)]]
}
fn kin(p:&[f64],q:&[f64],f:&mut [f64]) {
    put(f,0,vec(q,0));putmat(f,27,quaternion(&q[3..7]));
    for j in 0..8 {
        let parent=p[63+j] as usize;let r=mat(f,27+9*parent);let axis=vec(p,71+3*j);
        let anchor=add(vec(f,3*parent),mv(r,vec(p,95+3*j)));
        let child=mm(r,rotation(axis,q[7+j]));
        put(f,3*(j+1),sub(anchor,mv(child,vec(p,119+3*j))));putmat(f,27+9*(j+1),child);
        put(f,135+3*j,anchor);put(f,159+3*j,mv(r,axis));
    }
    let mut com=[0.;3];let mass=p[..9].iter().sum::<f64>();
    for i in 0..9 {
        let center=add(vec(f,3*i),mv(mat(f,27+9*i),vec(p,9+3*i)));put(f,108+3*i,center);
        com=add(com,scale(center,p[i]));
    }
    put(f,183,scale(com,1./mass));
}
fn jac(p:&[f64],f:&[f64],mut body:usize,point:V)->([[f64;14];3],[[f64;14];3]) {
    let mut l=[[0.;14];3];let mut a=[[0.;14];3];
    let offset=sub(point,vec(f,0));
    for i in 0..3 {
        l[i][i]=1.;a[i][3+i]=1.;
        let mut unit=[0.;3];unit[i]=1.;let v=cross(unit,offset);
        for k in 0..3 {l[k][3+i]=v[k];}
    }
    while body>0 {
        let j=body-1;let axis=vec(f,159+3*j);let v=cross(axis,sub(point,vec(f,135+3*j)));
        for k in 0..3 {l[k][6+j]=v[k];a[k][6+j]=axis[k];}
        body=p[63+j] as usize;
    }
    (l,a)
}
fn inertia(p:&[f64],f:&[f64],body:usize)->M {
    let r=mat(f,27+9*body);let d=vec(p,36+3*body);let mut a=[[0.;3];3];
    for i in 0..3 {for j in 0..3 {for k in 0..3 {a[i][j]+=r[i][k]*d[k]*r[j][k];}}}a
}
fn motion(p:&[f64],f:&[f64],v:&[f64],a:&[f64])->[f64;162] {
    let mut out=[0.;162];put(&mut out,0,vec(v,0));put(&mut out,27,vec(v,3));
    put(&mut out,54,vec(a,0));put(&mut out,81,vec(a,3));
    for j in 0..8 {
        let parent=p[63+j] as usize;let child=j+1;let axis=vec(f,159+3*j);
        let wp=vec(&out,27+3*parent);let ap=vec(&out,81+3*parent);
        let wc=add(wp,scale(axis,v[6+j]));
        let ac=add(add(ap,scale(axis,a[6+j])),scale(cross(wp,axis),v[6+j]));
        let rp=sub(vec(f,135+3*j),vec(f,3*parent));
        let va=add(vec(&out,3*parent),cross(wp,rp));
        let aa=add(add(vec(&out,54+3*parent),cross(ap,rp)),cross(wp,cross(wp,rp)));
        let rc=sub(vec(f,3*child),vec(f,135+3*j));
        put(&mut out,3*child,add(va,cross(wc,rc)));put(&mut out,27+3*child,wc);
        put(&mut out,54+3*child,add(add(aa,cross(ac,rc)),cross(wc,cross(wc,rc))));
        put(&mut out,81+3*child,ac);
    }
    for i in 0..9 {
        let offset=sub(vec(f,108+3*i),vec(f,3*i));let omega=vec(&out,27+3*i);
        let cv=add(vec(&out,3*i),cross(omega,offset));
        let ca=add(add(vec(&out,54+3*i),cross(vec(&out,81+3*i),offset)),cross(omega,cross(omega,offset)));
        put(&mut out,108+3*i,cv);put(&mut out,135+3*i,ca);
    }
    out
}
fn mass(p:&[f64],f:&[f64],out:&mut [f64]) {
    out.fill(0.);
    for body in 0..9 {
        let (l,a)=jac(p,f,body,vec(f,108+3*body));let inertia=inertia(p,f,body);
        let mut ia=[[0.;14];3];for k in 0..3 {for j in 0..14 {for t in 0..3 {ia[k][j]+=inertia[k][t]*a[t][j];}}}
        for i in 0..14 {for j in 0..14 {
            let mut linear=0.;let mut angular=0.;
            for k in 0..3 {linear+=l[k][i]*l[k][j];angular+=a[k][i]*ia[k][j];}
            out[i*14+j]+=p[body]*linear+angular;
        }}
    }
    for j in 0..8 {out[(6+j)*14+6+j]+=p[143+j];}
}
fn inverse(p:&[f64],f:&[f64],v:&[f64],a:&[f64],g:V,out:&mut [f64]) {
    let m=motion(p,f,v,a);out.fill(0.);
    for body in 0..9 {
        let (l,jac_a)=jac(p,f,body,vec(f,108+3*body));let ii=inertia(p,f,body);
        let force=scale(sub(vec(&m,135+3*body),g),p[body]);let omega=vec(&m,27+3*body);
        let moment=add(mv(ii,vec(&m,81+3*body)),cross(omega,mv(ii,omega)));
        for j in 0..14 {
            let mut lf=0.;let mut am=0.;for k in 0..3 {lf+=l[k][j]*force[k];am+=jac_a[k][j]*moment[k];}
            out[j]+=lf+am;
        }
    }
    for j in 0..8 {out[6+j]+=p[143+j]*a[6+j];}
}
// ABI callers own valid, nonoverlapping buffers of the supplied lengths.
#[no_mangle]
pub unsafe extern "C" fn lc_kin(p:*const f64,pn:usize,q:*const f64,qn:usize,out:*mut f64,on:usize)->i32 {
    if p.is_null()||q.is_null()||out.is_null()||pn!=P||qn!=15||on!=F{return 1;}
    let p=slice::from_raw_parts(p,pn);let q=slice::from_raw_parts(q,qn);
    if !proper(p)||!q.iter().all(|x|x.is_finite())||(q[3..7].iter().map(|x|x*x).sum::<f64>()-1.).abs()>1e-10{return 2;}
    let out=slice::from_raw_parts_mut(out,on);kin(p,q,out);
    if out.iter().all(|x|x.is_finite()){0}else{3}
}
#[no_mangle]
pub unsafe extern "C" fn lc_eval(p:*const f64,pn:usize,f:*const f64,fnn:usize,v:*const f64,a:*const f64,g:*const f64,mode:i32,out:*mut f64,on:usize)->i32 {
    if p.is_null()||f.is_null()||v.is_null()||a.is_null()||g.is_null()||out.is_null()||pn!=P||fnn!=F{return 1;}
    if !((mode==0&&on==196)||(mode==1&&on==162)||(mode==2&&on==14)){return 1;}
    let p=slice::from_raw_parts(p,pn);let f=slice::from_raw_parts(f,fnn);
    let v=slice::from_raw_parts(v,14);let a=slice::from_raw_parts(a,14);let g=slice::from_raw_parts(g,3);
    if !proper(p)||!f.iter().chain(v).chain(a).chain(g).all(|x|x.is_finite()){return 2;}
    let out=slice::from_raw_parts_mut(out,on);
    match mode {0=>mass(p,f,out),1=>out.copy_from_slice(&motion(p,f,v,a)),_=>inverse(p,f,v,a,vec(g,0),out)}
    if out.iter().all(|x|x.is_finite()){0}else{3}
}
fn cert(m:&[f64],q:&[f64],x:&[f64],blocks:&[f64])->[f64;3] {
    let n=x.len();let mut grad=vec![0.;n];
    for i in 0..n {for j in 0..n {grad[i]+=m[i*n+j]*x[j];}grad[i]+=q[i];}
    let (mut primal,mut dual,mut comp)=(0.0_f64,0.0_f64,0.0_f64);let mut off=0;
    for b in blocks.chunks_exact(2) {
        let d=b[0] as usize;let mu=b[1];
        if d==1 {primal=primal.max(-x[off]);dual=dual.max(-grad[off]);}
        else {
            let t=(x[off+1]*x[off+1]+x[off+2]*x[off+2]).sqrt();
            let gt=(grad[off+1]*grad[off+1]+grad[off+2]*grad[off+2]).sqrt();
            primal=primal.max(-x[off]).max(t-mu*x[off]);dual=dual.max(-grad[off]).max(mu*gt-grad[off]);
        }
        let mut dot=0.;for j in 0..d {dot+=x[off+j]*grad[off+j];}comp=comp.max(dot.abs());off+=d;
    }
    [primal,dual,comp]
}
fn accepted(c:[f64;3])->bool {c[0]<=1e-10&&c[1]<=1e-9&&c[2]<=1e-8}
#[no_mangle]
pub unsafe extern "C" fn lc_cones(m:*const f64,mn:usize,q:*const f64,n:usize,b:*const f64,bn:usize,l:f64,beta:f64,out:*mut f64,on:usize)->i32 {
    if m.is_null()||q.is_null()||b.is_null()||out.is_null()||n==0||n>104||mn!=n*n||bn%2!=0||bn>208||on!=n+5{return 1;}
    let m=slice::from_raw_parts(m,mn);let q=slice::from_raw_parts(q,n);let blocks=slice::from_raw_parts(b,bn);
    if !m.iter().chain(q).chain(blocks).all(|x|x.is_finite())||!l.is_finite()||l<=0.||!beta.is_finite()||!(0.0..1.0).contains(&beta){return 2;}
    let mut size=0;
    for block in blocks.chunks_exact(2) {
        if !((block[0]==1.)||(block[0]==3.&&block[1]>0.)){return 2;}size+=block[0] as usize;
    }
    if size!=n{return 2;}
    let mut x=vec![0.;n];let mut y=x.clone();let mut new=x.clone();let mut steps=0;
    for iteration in 1..=5000 {
        for i in 0..n {let mut sum=0.;for j in 0..n {sum+=m[i*n+j]*y[j];}new[i]=y[i]-(sum+q[i])/l;}
        let mut off=0;
        for block in blocks.chunks_exact(2) {
            let d=block[0] as usize;let mu=block[1];
            if d==1 {new[off]=new[off].max(0.);}
            else {
                let normal=new[off];let t=(new[off+1]*new[off+1]+new[off+2]*new[off+2]).sqrt();
                if !(normal>=0.&&t<=mu*normal) {
                    if normal+mu*t>0. {
                        let nnew=(normal+mu*t)/(1.+mu*mu);new[off]=nnew;
                        new[off+1]=mu*nnew*new[off+1]/t;new[off+2]=mu*nnew*new[off+2]/t;
                    }else{new[off..off+3].fill(0.);}
                }
            }
            off+=d;
        }
        for i in 0..n {y[i]=new[i]+beta*(new[i]-x[i]);x[i]=new[i];}
        steps=iteration;
        if iteration==1||iteration%8==0 {if accepted(cert(m,q,&x,blocks)){break;}}
    }
    let c=cert(m,q,&x,blocks);let out=slice::from_raw_parts_mut(out,on);
    out[..n].copy_from_slice(&x);out[n]=steps as f64;out[n+1..n+4].copy_from_slice(&c);out[n+4]=if accepted(c){1.}else{0.};
    if out.iter().all(|x|x.is_finite()){0}else{3}
}

#[no_mangle]
pub unsafe extern "C" fn lc_jac(p:*const f64,pn:usize,f:*const f64,fnn:usize,body:usize,point:*const f64,out:*mut f64,on:usize)->i32 {
    if p.is_null()||f.is_null()||point.is_null()||out.is_null()||pn!=P||fnn!=F||body>=9||on!=84{return 1;}
    let p=slice::from_raw_parts(p,pn);let f=slice::from_raw_parts(f,fnn);let point=slice::from_raw_parts(point,3);
    if !proper(p)||!f.iter().chain(point).all(|x|x.is_finite()){return 2;}
    let (l,a)=jac(p,f,body,vec(point,0));let out=slice::from_raw_parts_mut(out,on);
    for k in 0..3 {out[k*14..k*14+14].copy_from_slice(&l[k]);out[42+k*14..42+k*14+14].copy_from_slice(&a[k]);}
    if out.iter().all(|x|x.is_finite()){0}else{3}
}
