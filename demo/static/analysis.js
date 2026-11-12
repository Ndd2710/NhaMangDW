'use strict';
const Analysis={
  filters:{type:'',network:'',region:''},group:'networks',data:null,dataKey:null,busy:false,owner:null,serial:0,message:'',failed:false,
  groups:{networks:'Nhà mạng',regions:'Ba miền',plans:'Gói cước',provinces:'Tỉnh / thành'},
  key(){return new URLSearchParams({month:$('month').value,warehouse:0,...this.filters,subscriber:''}).toString();},
  ready(){return !!this.data&&this.dataKey===this.key();},
  enter(){if(this.owner!==state.user.username){this.owner=state.user.username;this.serial++;this.busy=false;this.filters={type:'',network:'',region:''};this.data=null;this.dataKey=null;this.message='';this.group='networks';}this.render();$('data-status').textContent=this.ready()?'Phân tích từ kho · Đọc lúc '+utc(this.data.readAt):'Chọn điều kiện và bấm Xem phân tích';},
  rows(group=this.group){return (this.data?.rows||[]).filter(r=>r.GocNhin===group).sort((a,b)=>Number(b.DoanhThu)-Number(a.DoanhThu)||String(a.Ma).localeCompare(String(b.Ma),'vi'));},
  trend(){
    const m=$('month').value,days=new Date(Date.UTC(Number(m.slice(0,4)),Number(m.slice(4)),0)).getUTCDate();
    const map=new Map(this.rows('days').map(r=>[r.Ma,r]));
    const values=Array.from({length:days},(_,i)=>{const date=m.slice(0,4)+'-'+m.slice(4)+'-'+String(i+1).padStart(2,'0');return {date,day:i+1,value:Number(map.get(date)?.DoanhThu||0)};});
    const max=Math.max(...values.map(r=>r.value),1),x=i=>50+i*860/Math.max(1,days-1),y=v=>210-v/max*170;
    const path=values.map((r,i)=>(i?'L':'M')+x(i).toFixed(2)+','+y(r.value).toFixed(2)).join(' ');
    return `<div class="analysis-trend"><svg viewBox="0 0 950 255" role="img" aria-label="Doanh thu cước theo ngày, đơn vị VND"><title>Doanh thu cước theo ngày, ${monthLabel()}</title><line x1="50" y1="210" x2="910" y2="210" stroke="#a9b8c4"/><line x1="50" y1="40" x2="910" y2="40" stroke="#e2e8ed"/><text x="50" y="27">${escapeHTML(number(max))} VND</text><text x="26" y="214">0</text><path d="${path}" fill="none" stroke="#2163a5" stroke-width="3"/>${values.map((r,i)=>`<circle cx="${x(i)}" cy="${y(r.value)}" r="4" fill="#2163a5" tabindex="0"><title>${r.date}: ${number(r.value)} VND</title></circle>`).join('')}${values.filter(r=>r.day===1||r.day===days||r.day%7===0).map(r=>`<text x="${x(r.day-1)}" y="238" text-anchor="middle">${String(r.day).padStart(2,'0')}</text>`).join('')}</svg></div><p class="explain">Ngày không phát sinh cước hiển thị 0. Rê chuột hoặc chuyển tiêu điểm đến từng điểm để xem số tiền. Đây là cước sử dụng mô phỏng, không bao gồm tiền nạp/thanh toán.</p>`;
  },
  render(){
    if(!state.user||state.view!=='analysis')return;
    $('page-title').textContent='Phân tích cước';$('page-description').textContent='So sánh nhà mạng, miền, gói cước và xu hướng trong tháng.';$('breadcrumb').textContent='Phân tích cước';$('month').closest('.period').hidden=false;
    document.querySelectorAll('#navigation [data-view]').forEach(a=>{a.classList.toggle('active',a.dataset.view==='analysis');if(a.dataset.view==='analysis')a.setAttribute('aria-current','page');else a.removeAttribute('aria-current');});
    const ready=this.ready(),total=ready?this.rows('total')[0]:null;
    const rows=ready?this.rows():[],share=r=>total?.DoanhThu?Number(r.DoanhThu)/Number(total.DoanhThu)*100:0;
    const top=rows.slice(0,10).map(r=>({...r,Nhan:r.Ma&&this.group==='plans'?r.Ma+' · '+r.Ten:r.Ten}));
    const tools=`<form id="analysis-filter" class="filterbar">${select('analysis-type','Dịch vụ',[{ID:'THOAI',Ten:'Thoại'},{ID:'DATA',Ten:'Data'}],this.filters.type)}${select('analysis-network','Nhà mạng',state.catalog.networks,this.filters.network)}${select('analysis-region','Tỉnh / thành',state.catalog.regions,this.filters.region)}<button id="analysis-apply" class="primary" ${this.busy?'disabled':''}>${this.busy?'Đang đọc…':'Xem phân tích'}</button><button id="analysis-clear" class="text-button" type="button">Xóa bộ lọc</button></form>`;
    let body='';
    if(!ready)body=panel('Chưa mở phân tích','Chọn tháng, điều kiện rồi bấm Xem phân tích','<p>Dữ liệu được đọc trực tiếp từ kho khi bạn yêu cầu.</p>');
    else if(!total?.SoBanGhi)body=panel('Không có dữ liệu','Không có cước cho điều kiện đã chọn','<p>Hãy đổi tháng hoặc bộ lọc. Chưa có phát sinh không được diễn giải thành doanh thu bị mất.</p>');
    else{
      const cols=[['Ma','Mã'],['Ten','Tên'],['SoBanGhi','Bản ghi',true],['SoThueBao','Thuê bao',true],['DoanhThu','Doanh thu (VND)',true],['TyTrong','Tỷ trọng (%)',true]];
      if(this.group==='plans')cols.splice(4,0,['DonGiaThoaiBinhQuan','VND/phút',true],['DonGiaDataBinhQuan','VND/MB',true]);
      body=`<div class="metric-grid">${metric('Doanh thu cước',total.DoanhThu,'VND',number(total.SoBanGhi)+' bản ghi trong phạm vi',true)}${metric('Thuê bao có phát sinh',total.SoThueBao,'thuê bao','Đếm phân biệt theo bộ lọc')}${metric('Phút thoại',total.SoPhutGoi,'phút',number(total.SoCuocGoi)+' cuộc thoại')}${metric('Dung lượng data',total.DungLuongDataMB,'MB','Phân tích riêng với phút thoại')}</div>`
      +`<div class="analysis-tabs" role="tablist" aria-label="Góc phân tích">${Object.entries(this.groups).map(([id,title])=>`<button type="button" role="tab" data-analysis-group="${id}" aria-selected="${id===this.group}" aria-controls="analysis-group" class="${id===this.group?'primary':'secondary'}">${title}</button>`).join('')}</div>`
      +`<div id="analysis-group" role="tabpanel">`+panel('Doanh thu theo '+this.groups[this.group].toLowerCase(),rows.length>10?'Biểu đồ hiển thị 10 nhóm có doanh thu lớn nhất; bảng và CSV chứa toàn bộ kết quả.':'Cùng tháng và cùng điều kiện đã chọn',bars(top,'DoanhThu','Nhan',true),'<button id="analysis-export" class="secondary">↓ Xuất CSV</button>')
      +panel('Bảng '+this.groups[this.group].toLowerCase(),number(rows.length)+' nhóm · Tỷ trọng theo tổng doanh thu đang lọc',table(rows.map(r=>({...r,TyTrong:share(r)})),cols))+'</div>'
      +panel('Xu hướng doanh thu theo ngày',monthLabel()+' · '+this.rows('days').length+' ngày có bản ghi · Cùng bộ lọc',this.trend(),'<button id="analysis-export-days" class="secondary">↓ CSV ngày phát sinh</button>')
      +help('Cách đọc và trình bày số liệu','Thuê bao toàn phạm vi được đếm phân biệt; không cộng số thuê bao giữa các gói vì một thuê bao có thể dùng nhiều gói. Tỷ trọng dùng tổng doanh thu của phạm vi đang chọn. Đơn giá bình quân bằng tổng tiền / tổng lượng; không có lượng thì để rỗng. Dữ liệu và biểu giá đều mô phỏng; không suy lợi nhuận hoặc thị phần thực tế.');
    }
    $('content').innerHTML=tools+`<div id="analysis-feedback" class="${this.failed?'error-panel':'notice'}" role="status" ${this.message?'':'hidden'}>${escapeHTML(this.message)}</div>`+body;
    $('analysis-filter').onsubmit=e=>{e.preventDefault();this.load();};
    for(const k of ['type','network','region'])$('analysis-'+k).onchange=e=>{this.filters[k]=e.target.value;this.message='Điều kiện đã đổi. Bấm Xem phân tích để cập nhật kết quả.';this.failed=false;this.render();};
    $('analysis-clear').onclick=()=>{this.filters={type:'',network:'',region:''};this.dataKey=null;this.message='Đã xóa bộ lọc. Bấm Xem phân tích.';this.failed=false;this.render();};
    document.querySelectorAll('[data-analysis-group]').forEach(b=>b.onclick=()=>{this.group=b.dataset.analysisGroup;this.render();});
    if($('analysis-export'))$('analysis-export').onclick=()=>this.export(this.group);
    if($('analysis-export-days'))$('analysis-export-days').onclick=()=>this.export('days');
  },
  async load(){
    if(this.busy)return;const key=this.key(),owner=state.user?.username,serial=++this.serial;
    this.busy=true;this.message='Đang đọc phân tích từ kho…';this.failed=false;this.render();
    try{const data=await api('/api/analysis?'+key);if(state.user?.username!==owner||serial!==this.serial)return;this.data=data;this.dataKey=key;this.message='Đã mở phân tích '+String(data.month).slice(4)+'/'+String(data.month).slice(0,4)+'.';if(state.view==='analysis')$('data-status').textContent=data.source+' · Đọc lúc '+utc(data.readAt);}
    catch(e){if(state.user?.username===owner&&serial===this.serial){this.dataKey=null;this.message=e.message+' Bấm Xem phân tích để thử lại.';this.failed=true;}}
    finally{if(serial===this.serial){this.busy=false;if(state.view==='analysis'&&state.user?.username===owner)this.render();}}
  },
  async export(group){
    if(!this.ready())return;
    try{const r=await fetch('/api/analysis/export?group='+group+'&'+this.dataKey);if(!r.ok){const d=await r.json();throw new Error(d.error);}
      const url=URL.createObjectURL(await r.blob()),a=document.createElement('a');a.href=url;a.download='phan-tich-'+group+'-'+$('month').value+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
    }catch(e){this.message=e.message;this.failed=true;this.render();}
  }
};
