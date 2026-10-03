"use strict";
(() => {
  const $ = id => document.getElementById(id);
  const canvas = $("canvas");
  const ctx = canvas.getContext("2d");
  const data = window.LOCO_REPLAY;
  if (!ctx || !data || data.mode !== "recorded_playback" || data.physical_acceptance_authority !== false) {
    $("status").textContent = "The local recording could not be loaded. Keep index.html, bundle.js, viewer.js and style.css together.";
    return;
  }
  const notes = {
    godot_jolt: "Godot/Jolt begins prone, stands, walks, receives the scheduled impulse and follows the recorded recovery route. This is the Explorer development session, not the six-cell R10DH acceptance campaign.",
    mujoco: "MuJoCo starts from its walking setup and receives a torso impulse. The original session published 749 pose frames over 2,992 native steps; the viewer keeps that original sampling.",
    rapier_parry: "Rapier/Parry starts from its walking setup and receives a torso impulse. All 3,172 published pose frames are included. Successful movement here does not establish general recovery."
  };
  let session, frame = 0, playing = false, time = 0, previousClock = null;
  let yaw = -.68, pitch = .43, zoom = 1, drag = null;
  let width = 1, height = 1, impulseIndex = -1, torsoIndex = 0;

  function setPlaying(value) {
    playing = value;
    previousClock = null;
    $("play").textContent = playing ? "Pause" : "Play";
    $("play").setAttribute("aria-label", playing ? "Pause recorded playback" : "Play recorded observations");
  }
  function choose() {
    session = data.sessions.find(item => item.engine === $("engine").value);
    if (!session || !session.frames.length) { $("status").textContent = "This recording is missing."; return; }
    setPlaying(false);
    frame = 0;
    time = session.frames[0][1];
    torsoIndex = session.bodies.findIndex(body => body.id === "torso");
    impulseIndex = session.frames.findIndex(item => item[5].length > 0);
    $("timeline").max = session.frames.length - 1;
    $("timeline").disabled = false;
    $("play").disabled = false;
    $("jump").disabled = impulseIndex < 0;
    $("source").textContent = session.source_commit;
    $("engine-note").textContent = notes[session.engine];
    $("status").textContent = "Paused. These are retained development observations.";
    update();
  }

  function update() {
    const row = session.frames[frame], torso = row[3][torsoIndex];
    $("timeline").value = frame;
    $("timeline").setAttribute("aria-valuetext", `Native frame ${row[0]}, ${row[1].toFixed(3)} simulation seconds`);
    $("time").textContent = `${row[1].toFixed(2)} / ${session.frames.at(-1)[1].toFixed(2)} s`;
    $("frame").textContent = row[0].toLocaleString();
    $("frame-count").textContent = `${(frame + 1).toLocaleString()} / ${session.published_frames.toLocaleString()} published poses`;
    $("height").textContent = `${torso[1].toFixed(3)} m`;
    $("distance").textContent = `${(torso[0] - session.frames[0][3][torsoIndex][0]).toFixed(3)} m`;
    $("contacts").textContent = `${row[4].filter(Boolean).length} / ${row[4].length}`;
    $("phase").textContent = row[2].replaceAll("_", " ");
    draw();
  }

  // Rotate the recorded geometry; only the camera changes the view.
  function rotate(v, q) {
    const [x,y,z,w] = q, [vx,vy,vz] = v;
    const tx = 2*(y*vz-z*vy), ty = 2*(z*vx-x*vz), tz = 2*(x*vy-y*vx);
    return [vx+w*tx+y*tz-z*ty, vy+w*ty+z*tx-x*tz, vz+w*tz+x*ty-y*tx];
  }
  function world(local, pose) {
    const v = rotate(local, pose.slice(3));
    return v.map((value, i) => value + pose[i]);
  }
  function project(point, target) {
    const dx=point[0]-target[0], dy=point[1]-.2, dz=point[2]-target[2];
    const horizontal=dx*Math.cos(yaw)-dz*Math.sin(yaw);
    const depth=dx*Math.sin(yaw)+dz*Math.cos(yaw);
    const vertical=dy*Math.cos(pitch)-depth*Math.sin(pitch);
    const scale=Math.min(width*.55,height*.85)*zoom;
    return [width*.5+horizontal*scale,height*.58-vertical*scale,depth*Math.cos(pitch)+dy*Math.sin(pitch),scale];
  }
  function line(a,b,color,lineWidth=1) {
    ctx.beginPath();ctx.moveTo(a[0],a[1]);ctx.lineTo(b[0],b[1]);ctx.strokeStyle=color;ctx.lineWidth=lineWidth;ctx.stroke();
  }
  function draw() {
    if (!session) return;
    ctx.clearRect(0,0,width,height);
    const row=session.frames[frame], target=row[3][torsoIndex];
    // A fixed world grid makes translation visible while the camera follows the torso.
    const gx=Math.floor(target[0]*4)/4,gz=Math.floor(target[2]*4)/4;
    for(let i=-12;i<=12;i++) {
      line(project([gx+i*.25,0,gz-3],target),project([gx+i*.25,0,gz+3],target),"#263538");
      line(project([gx-3,0,gz+i*.25],target),project([gx+3,0,gz+i*.25],target),"#263538");
    }
    const ordered=session.bodies.map((body,i)=>({body,i,depth:project(row[3][i],target)[2]})).sort((a,b)=>b.depth-a.depth);
    for (const {body,i} of ordered) {
      const pose=row[3][i], collision=body.collision;
      if (collision.kind === "box") {
        const s=collision.size_m, corners=[];
        for(const x of [-1,1]) for(const y of [-1,1]) for(const z of [-1,1]) corners.push(project(world([x*s.x/2,y*s.y/2,z*s.z/2],pose),target));
        ctx.fillStyle="#749a8555";
        for(const face of [[0,1,3,2],[4,5,7,6],[0,1,5,4],[2,3,7,6],[0,2,6,4],[1,3,7,5]]) {
          ctx.beginPath(); face.forEach((n,j)=>j?ctx.lineTo(corners[n][0],corners[n][1]):ctx.moveTo(corners[n][0],corners[n][1]));ctx.closePath();ctx.fill();
        }
        for(let a=0;a<8;a++) for(let b=a+1;b<8;b++) if([1,2,4].includes(a^b)) line(corners[a],corners[b],"#b7e0c6",1.5);
      } else if (collision.kind === "capsule") {
        const a=project(world([0,-collision.length_m/2,0],pose),target), b=project(world([0,collision.length_m/2,0],pose),target);
        ctx.lineCap="round";
        line(a,b,body.id.includes("left")?"#93c7b0":"#7196a9",Math.max(3,collision.radius_m*2*a[3]));
        line(a,b,"#d5ede140",1);
        ctx.lineCap="butt";
      }
      if (row[4][i]) {
        const p=project([pose[0],.002,pose[2]],target);
        ctx.beginPath();ctx.ellipse(p[0],p[1],5,2.5,0,0,2*Math.PI);ctx.fillStyle="#a3dfbd";ctx.fill();
      }
    }
    if(row[5].length) {
      const p=project(target,target);ctx.strokeStyle="#f3bc78";ctx.lineWidth=2;ctx.beginPath();ctx.arc(p[0],p[1],40,0,2*Math.PI);ctx.stroke();
      ctx.fillStyle="#f3bc78";ctx.font="12px system-ui";ctx.fillText("Recorded impulse",p[0]+46,p[1]);
    }
  }
  function resize() {
    const box=canvas.getBoundingClientRect(), ratio=window.devicePixelRatio||1;
    width=box.width;height=box.height;canvas.width=Math.round(width*ratio);canvas.height=Math.round(height*ratio);
    ctx.setTransform(ratio,0,0,ratio,0,0);draw();
  }
  function animate(clock) {
    if(playing && session) {
      if(previousClock !== null) time += (clock-previousClock)/1000*Number($("speed").value);
      const end=session.frames.at(-1)[1];
      while(frame < session.frames.length-1 && session.frames[frame+1][1] <= time) frame++;
      if(time >= end) {time=end;setPlaying(false);$("status").textContent="End of retained session. Play starts it again.";}
      update();
    }
    previousClock=clock;requestAnimationFrame(animate);
  }
  $("engine").addEventListener("change",choose);
  $("play").addEventListener("click",()=>{
    if(!playing && frame === session.frames.length-1) {frame=0;time=session.frames[0][1];}
    setPlaying(!playing);$("status").textContent=playing?"Playing retained observations at the selected simulation-time rate.":"Paused.";
  });
  $("timeline").addEventListener("input",()=>{setPlaying(false);frame=Number($("timeline").value);time=session.frames[frame][1];$("status").textContent="Paused at the selected published pose.";update();});
  $("jump").addEventListener("click",()=>{if(impulseIndex<0)return;setPlaying(false);frame=impulseIndex;time=session.frames[frame][1];$("status").textContent="At the first published frame carrying the recorded impulse. No impulse is being applied now.";update();});
  $("reset-view").addEventListener("click",()=>{yaw=-.68;pitch=.43;zoom=1;draw();});
  canvas.addEventListener("pointerdown",event=>{drag=[event.clientX,event.clientY];canvas.setPointerCapture(event.pointerId);});
  canvas.addEventListener("pointermove",event=>{if(!drag)return;yaw+=(event.clientX-drag[0])*.008;pitch=Math.max(.1,Math.min(1.3,pitch+(event.clientY-drag[1])*.006));drag=[event.clientX,event.clientY];draw();});
  const endDrag=()=>{drag=null;};
  canvas.addEventListener("pointerup",endDrag);canvas.addEventListener("pointercancel",endDrag);canvas.addEventListener("lostpointercapture",endDrag);
  canvas.addEventListener("wheel",event=>{event.preventDefault();zoom=Math.max(.45,Math.min(2.5,zoom*Math.exp(-event.deltaY*.001)));draw();},{passive:false});
  document.addEventListener("visibilitychange",()=>{if(document.hidden){setPlaying(false);$("status").textContent="Paused while the viewer is out of view.";}});
  new ResizeObserver(resize).observe(canvas);
  choose();resize();requestAnimationFrame(animate);
})();
