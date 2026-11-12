'use strict';
const $ = id => document.getElementById(id);
const escapeHTML = v => String(v ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const number = v => v === null || v === undefined ? '—' : new Intl.NumberFormat('vi-VN', {maximumFractionDigits:2}).format(v);
const sum = (rows,key) => rows.reduce((n,r)=>n+Number(r[key]??0),0);
const ratio = (a,b) => b ? a/b : null;
const state = {user:null,view:'overview',data:null,catalog:null,cube:null,admin:null,jobs:[],filters:{warehouse:'0',type:'',network:'',region:'',subscriber:''},dataKey:null,reportRuns:{},reportBusy:false,adminStatus:'',errorSource:'',request:0};
let poll=null;
const reportViews=new Set(['overview','sales','purchases','inventory','goods','telecom']);
const formViews=new Set(['sales','purchases','inventory','goods','telecom']);
const adminViews=new Set(['dashboard','operations','batches','errors','watermarks']);
const titles = {
  dashboard:['Trang quản trị viên','Theo dõi hệ thống và chọn chức năng vận hành.','Trang quản trị viên'],
  overview:['Trang nhân viên','Chọn một chức năng để bắt đầu xem báo cáo.','Trang chủ'],
  sales:['Báo cáo bán hàng','Số lượng bán, doanh thu và đơn giá bình quân.','Bán hàng'],
  purchases:['Báo cáo mua hàng','Hàng đã nhận và giá trị mua trong kỳ.','Mua hàng'],
  inventory:['Báo cáo tồn kho','Số lượng tồn đúng ngày chốt cuối tháng.','Tồn kho'],
  goods:['Đối chiếu hàng hóa','So sánh mua, bán và tồn ở cùng nhóm sản phẩm.','Đối chiếu hàng hóa'],
  telecom:['Cước dịch vụ','Lượng sử dụng và doanh thu thoại, data.','Cước dịch vụ'],
  cube:['Đối soát SQL / cube','Kiểm tra chín chỉ tiêu ở cùng tháng.','Đối soát SQL / cube'],
  operations:['Nạp & xử lý cube','Chọn tác vụ cần thực hiện và theo dõi tiến độ.','Nạp & xử lý cube'],
  batches:['Lịch sử nạp dữ liệu','Các đợt nạp gần nhất, theo thời gian Việt Nam.','Lịch sử nạp'],
  errors:['Dữ liệu lỗi','Những dòng bị cách ly và lý do cần kiểm tra.','Dữ liệu lỗi'],
  watermarks:['Mốc nạp dữ liệu','ID nguồn cuối cùng đã xử lý thành công.','Mốc nạp dữ liệu']
};
async function api(path,body,signal){
  const controller=new AbortController();
  const timer=setTimeout(()=>controller.abort(),65000);
  const abort=()=>controller.abort();signal?.addEventListener('abort',abort,{once:true});
  try{
    const options={signal:controller.signal};
    if(body!==undefined)Object.assign(options,{method:'POST',headers:{'Content-Type':'application/json','X-CSRF-Token':state.user?.csrf??''},body:JSON.stringify(body)});
    const response=await fetch(path,options);const data=await response.json();
    if(!response.ok){if(response.status===401&&path!='/api/login')showLogin();const e=new Error(data.error||'Không thực hiện được yêu cầu.');e.status=response.status;e.code=data.code;throw e;}
    return data;
  }catch(e){if(e.name==='AbortError')throw new Error('Báo cáo tải quá lâu hoặc yêu cầu đã hủy. Hãy thử lại.');throw e;}
  finally{clearTimeout(timer);signal?.removeEventListener('abort',abort);}
}
function query(scope=state.view) {
  const filters={warehouse:'0',type:'',network:'',region:'',subscriber:''};
  if(['sales','purchases','inventory','goods'].includes(scope))filters.warehouse=state.filters.warehouse;
  if(scope==='telecom')for(const k of ['type','network','region','subscriber'])filters[k]=state.filters[k];
  return new URLSearchParams({month:$('month').value,...filters}).toString();
}
function error(message){$('page-error').textContent=message;$('page-error').hidden=!message;}
function notice(message){$('notice').textContent=message;$('notice').hidden=!message;}
function metric(label,value,unit,hint,teal=false){return `<div class="metric ${teal?'teal':''}"><span class="label">${escapeHTML(label)}</span><span class="value">${number(value)}</span><span class="unit">${escapeHTML(unit)}</span><span class="hint">${escapeHTML(hint)}</span></div>`;}
function badge(status){const labels={SUCCESS:'Thành công',FAILED:'Thất bại',RUNNING:'Đang chạy',success:'Thành công',failed:'Thất bại',running:'Đang chạy'};return `<span class="badge ${escapeHTML(status.toLowerCase())}">${escapeHTML(labels[status]??status)}</span>`;}
function reason(value){const names={DUPLICATE_LINE:'Trùng dòng chứng từ',INVALID_DATE:'Ngày không hợp lệ',INVALID_NUMBER:'Số lượng hoặc giá không hợp lệ',MISSING_MAPPING:'Thiếu ánh xạ mã nguồn',TRUNG_MA_SU_DUNG:'Trùng mã sử dụng',NGAY_KHONG_HOP_LE:'Ngày không hợp lệ',SO_DO_KHONG_HOP_LE:'Số đo không hợp lệ',THIEU_DANH_MUC:'Thiếu mã trong danh mục',GIA_DICH_VU_CAN_MA_PHIEN_BAN_MOI:'Đổi giá cần mã dịch vụ mới',NGAY_TRUOC_DANG_KY:'Sử dụng trước ngày đăng ký'};return escapeHTML(names[value]??value);}
function panel(title,subtitle,body,extra=''){return `<section class="panel"><div class="panel-head"><div><h2>${escapeHTML(title)}</h2><p class="panel-sub">${escapeHTML(subtitle)}</p></div>${extra}</div>${body}</section>`;}
function table(rows,cols){if(!rows.length)return '<div class="empty">Không có dữ liệu cho điều kiện đã chọn. Hãy đổi bộ lọc.</div>';return `<div class="table-wrap"><table><thead><tr>${cols.map(c=>`<th class="${c[2]?'num':''}">${escapeHTML(c[1])}</th>`).join('')}</tr></thead><tbody>${rows.map(r=>`<tr>${cols.map(c=>`<td class="${c[2]?'num':''}">${c[3]?c[3](r[c[0]]):c[2]?number(r[c[0]]):escapeHTML(r[c[0]])}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;}
function bars(rows,key,label,teal=false){const max=Math.max(...rows.map(r=>Number(r[key])),1);return `<div class="chart">${rows.map(r=>`<div><div class="bar-label"><span>${escapeHTML(r[label])}</span><strong>${number(r[key])}</strong></div><div class="bar-track"><div class="bar-fill ${teal?'teal':''}" style="width:${Math.max(0,Number(r[key])/max*100)}%"></div></div></div>`).join('')}</div>`;}
function columnChart(rows,key,label,unit='VND'){
  const data=rows.filter(r=>r[key]!==null&&r[key]!==undefined);
  if(!data.length)return '<div class="empty">Chưa có dữ liệu để vẽ biểu đồ.</div>';
  const max=Math.max(...data.map(r=>Number(r[key])),1),slot=840/data.length,width=Math.min(120,slot*.55);
  return `<div class="report-chart"><svg viewBox="0 0 960 330" role="img" aria-label="Biểu đồ cột, đơn vị ${escapeHTML(unit)}"><title>Biểu đồ theo ${escapeHTML(unit)}</title><text x="60" y="22">${escapeHTML(unit)}</text><line x1="60" y1="260" x2="910" y2="260" stroke="#98aabb"/>${data.map((r,i)=>{const x=60+slot*(i+.5),height=Number(r[key])/max*190;return `<g tabindex="0"><title>${escapeHTML(r[label])}: ${number(r[key])} ${escapeHTML(unit)}</title><rect x="${x-width/2}" y="${260-height}" width="${width}" height="${height}" rx="4" fill="${['#2163a5','#218a61','#778899','#9165a6'][i%4]}"/><text x="${x}" y="${246-height}" text-anchor="middle" class="chart-value">${number(r[key])}</text><text x="${x}" y="292" text-anchor="middle">${escapeHTML(r[label])}</text></g>`;}).join('')}</svg></div>`;
}
function telecomChart(rows){const totals=new Map();for(const r of rows)totals.set(r.TenNhaMang,(totals.get(r.TenNhaMang)||0)+Number(r.DoanhThu));return columnChart([...totals].map(([Ten,DoanhThu])=>({Ten,DoanhThu})),'DoanhThu','Ten');}
function options(rows,value){return rows.map(r=>`<option value="${escapeHTML(r.ID)}" ${String(r.ID)===value?'selected':''}>${escapeHTML(r.Ten)}</option>`).join('');}
function select(id,label,rows,value,all='Tất cả'){return `<div><label for="${id}">${label}</label><select id="${id}"><option value="">${all}</option>${options(rows,value)}</select></div>`;}
function utc(text){return text?new Date(text.endsWith('Z')?text:text+'Z').toLocaleString('vi-VN',{timeZone:'Asia/Ho_Chi_Minh',hour12:false}):'—';}
function snapshot(){const c=state.data.coverage[0];return c.SoCapDaChot===c.SoCapCanCo && c.SoCapCanCo>0;}
function goodsTotal(key){if(key==='SoLuongTon' && !snapshot())return null;return sum(state.data.goods,key);}
function updatePeriods(){const selected=$('month').value;const rows=state.catalog?.months;if(!rows?.length)return;$('month').innerHTML=options(rows,selected);if(rows.some(r=>String(r.ID)===selected))$('month').value=selected;}
function monthLabel(){const m=$('month').value;return `${m.slice(4)}/${m.slice(0,4)}`;}
function help(title,text){return `<details class="help-details"><summary>${escapeHTML(title)}</summary><p>${escapeHTML(text)}</p></details>`;}
function reportReady(){return !!state.data && state.dataKey===query() && state.reportRuns[state.view]===query();}
function reportPrompt(){return '<section class="panel report-prompt"><h2>Chưa mở báo cáo</h2><p>Chọn tháng và điều kiện ở trên, rồi bấm <strong>Xem báo cáo</strong> để hiển thị kết quả.</p></section>';}
function feedback(kind,message){$('report-feedback').hidden=!message;$('report-feedback').className='report-feedback '+kind;$('report-feedback-text').textContent=message;$('retry-report').hidden=kind!=='failed';}
function setReportBusy(busy){state.reportBusy=busy;for(const id of ['apply-goods','apply-telecom']){const b=$(id);if(b){b.disabled=busy;b.textContent=busy?'Đang lấy báo cáo…':'Xem báo cáo';}}if(formViews.has(state.view))document.querySelectorAll('[data-export]').forEach(b=>b.disabled=busy||!reportReady());$('refresh').disabled=busy;$('loading').hidden=!busy;$('content').setAttribute('aria-busy',String(busy));}
function warehouseTools(kind){return `<div class="page-tools"><div class="filterbar"><div><label for="warehouse">Kho hàng</label><select id="warehouse"><option value="0">Tất cả kho hàng</option>${options(state.catalog.warehouses,state.filters.warehouse)}</select></div><button class="primary" id="apply-goods">Xem báo cáo</button></div><button class="secondary" data-export="${kind}">↓ Xuất CSV</button></div>`;}
function overview(){
  const t=state.data.telecom;
  const links=[['sales','↗','Bán hàng','Doanh thu và lượng hàng bán'],['purchases','↙','Mua hàng','Lượng hàng nhận và giá trị mua'],['inventory','▤','Tồn kho','Tồn chốt đúng ngày cuối kỳ'],['telecom','⌁','Cước dịch vụ','Phút thoại, dung lượng và doanh thu'],['analysis','▥','Phân tích cước & biểu đồ','Nhà mạng, ba miền, gói và xu hướng ngày']];
  return `<div class="metric-grid">${metric('Doanh thu bán hàng',goodsTotal('DoanhThu'),'VND',monthLabel())}${metric('Số lượng bán',goodsTotal('SoLuongBan'),'đơn vị',monthLabel())}${metric('Tồn cuối kỳ',goodsTotal('SoLuongTon'),'đơn vị','Ngày cuối tháng',true)}${metric('Doanh thu cước',sum(t,'DoanhThu'),'VND',monthLabel(),true)}</div>`
    +panel('Biểu đồ doanh thu bán hàng',monthLabel()+' · VND',columnChart(state.data.goods,'DoanhThu','NhomSanPham'))
    +panel('Biểu đồ cước theo nhà mạng',monthLabel()+' · VND',telecomChart(t))
    +panel('Chức năng báo cáo','Mỗi chức năng mở một trang riêng',`<div class="shortcut-grid">${links.map(([view,icon,label,text])=>`<a class="shortcut" href="#/${view}" data-go="${view}"><span class="icon">${icon}</span><span><strong>${label}</strong><small>${text}</small></span><span class="arrow">→</span></a>`).join('')}</div>`);
}
function sales(){
  if(!reportReady())return warehouseTools('sales')+reportPrompt();
  const rows=state.data.goods.map(r=>({...r,DonGiaBinhQuan:ratio(r.DoanhThu,r.SoLuongBan)}));
  return warehouseTools('sales')+`<div class="metric-grid three">${metric('Số lượng bán',goodsTotal('SoLuongBan'),'đơn vị','Trong tháng')}${metric('Doanh thu bán',goodsTotal('DoanhThu'),'VND','Không bao gồm cước',true)}${metric('Đơn giá bình quân',ratio(goodsTotal('DoanhThu'),goodsTotal('SoLuongBan')),'VND/đơn vị','Tổng doanh thu / tổng lượng')}</div>`
    +panel('Biểu đồ doanh thu bán',monthLabel()+' · VND',columnChart(rows,'DoanhThu','NhomSanPham'))
    +panel('Bán hàng theo nhóm sản phẩm',monthLabel(),table(rows,[['NhomSanPham','Nhóm sản phẩm'],['SoLuongBan','Số lượng bán',true],['DoanhThu','Doanh thu (VND)',true],['DonGiaBinhQuan','Đơn giá bình quân',true]])+help('Cách đọc báo cáo','Bình quân được tính từ tổng tiền chia tổng lượng. Nhóm không bán giữ lượng 0 và bình quân rỗng.'));
}
function purchases(){
  if(!reportReady())return warehouseTools('purchases')+reportPrompt();
  const rows=state.data.goods.map(r=>({...r,DonGiaBinhQuan:ratio(r.ThanhTienMua,r.SoLuongMua)}));
  return warehouseTools('purchases')+`<div class="metric-grid three">${metric('Số lượng mua',goodsTotal('SoLuongMua'),'đơn vị','Hàng đã nhận')}${metric('Giá trị mua',goodsTotal('ThanhTienMua'),'VND','Trong tháng',true)}${metric('Đơn giá bình quân',ratio(goodsTotal('ThanhTienMua'),goodsTotal('SoLuongMua')),'VND/đơn vị','Tổng tiền mua / tổng lượng')}</div>`
    +panel('Biểu đồ giá trị mua',monthLabel()+' · VND',columnChart(rows,'ThanhTienMua','NhomSanPham'))
    +panel('Mua hàng theo nhóm sản phẩm',monthLabel(),table(rows,[['NhomSanPham','Nhóm sản phẩm'],['SoLuongMua','Số lượng mua',true],['ThanhTienMua','Giá trị mua (VND)',true],['DonGiaBinhQuan','Đơn giá bình quân',true]])+help('Phạm vi giá trị mua','Báo cáo ghi hàng đã nhận vào kho. Giá trị mua không phải giá vốn hàng đã bán và chưa đủ để tính lợi nhuận.'));
}
function inventory(){
  if(!reportReady())return warehouseTools('inventory')+reportPrompt();
  const c=state.data.coverage[0];
  return warehouseTools('inventory')+`<div class="metric-grid three">${metric('Tồn cuối kỳ',goodsTotal('SoLuongTon'),'đơn vị','Đúng ngày cuối tháng',true)}${metric('Số cặp đã chốt',c.SoCapDaChot,'cặp','Sản phẩm – kho')}${metric('Số cặp cần có',c.SoCapCanCo,'cặp',snapshot()?'Đủ dữ liệu chốt':'Cần kiểm tra')}</div>`
    +panel('Biểu đồ tồn cuối kỳ',monthLabel()+' · Đơn vị',snapshot()?columnChart(state.data.goods,'SoLuongTon','NhomSanPham','đơn vị'):'<div class="empty">Chưa đủ dữ liệu chốt tồn để vẽ biểu đồ.</div>')
    +panel('Tồn kho theo nhóm sản phẩm',monthLabel(),table(state.data.goods,[['NhomSanPham','Nhóm sản phẩm'],['SoLuongTon','Số lượng tồn cuối kỳ',true]])+help('Nguyên tắc chốt tồn','Tồn lấy đúng ngày cuối tháng, không cộng tồn qua ngày. Thiếu snapshot được báo và không đổi thành 0. Nhóm dự phòng có tồn nhưng không bán vẫn xuất hiện.'),'<a href="#/goods" data-go="goods" class="section-link">Đối chiếu mua – bán – tồn →</a>');
}
function goods(){if(!reportReady())return warehouseTools('goods')+reportPrompt();return warehouseTools('goods')+panel('Đối chiếu mua · bán · tồn',monthLabel(),table(state.data.goods,[['NhomSanPham','Nhóm sản phẩm'],['SoLuongMua','Lượng mua',true],['SoLuongBan','Lượng bán',true],['SoLuongTon','Tồn cuối kỳ',true],['DoanhThu','Doanh thu (VND)',true],['ThanhTienMua','Giá trị mua (VND)',true]])+help('Cách đối chiếu nhiều nghiệp vụ','Mỗi fact được tổng hợp riêng rồi mới kết hợp theo nhóm. Tồn chỉ lấy ngày chốt, không nhân với số dòng mua hoặc bán.'));}
function telecom(){
  const t=state.data?.telecom??[];
  const pages=Math.max(1,Math.ceil(t.length/100)),page=Math.min(state.telecomPage||1,pages);
  const pageRows=t.slice((page-1)*100,page*100);
  const controls= `<div class="page-tools"><div class="filterbar">${select('type','Dịch vụ',[{ID:'THOAI',Ten:'Thoại'},{ID:'DATA',Ten:'Data'}],state.filters.type)}${select('network','Nhà mạng',state.catalog.networks,state.filters.network)}<button id="apply-telecom" class="primary">Xem báo cáo</button><button id="clear-telecom" class="text-button">Xóa bộ lọc</button></div><button class="secondary" data-export="telecom">↓ Xuất CSV</button></div>`
    +`<details class="advanced-filters" ${state.filters.region||state.filters.subscriber?'open':''}><summary>Lọc thêm theo khu vực và thuê bao</summary><div class="filterbar">${select('region','Khu vực',state.catalog.regions,state.filters.region)}${select('subscriber','Thuê bao',state.catalog.subscribers,state.filters.subscriber)}</div></details>`
    ;
  if(!reportReady())return controls+reportPrompt();
  return controls+`<div class="metric-grid three">${metric('Doanh thu cước',sum(t,'DoanhThu'),'VND','Điều kiện đang chọn',true)}${metric('Phút thoại',sum(t,'SoPhutGoi'),'phút',number(sum(t,'SoCuocGoi'))+' cuộc thoại')}${metric('Dung lượng data',sum(t,'DungLuongDataMB'),'MB',number(sum(t,'SoBanGhi'))+' bản ghi sử dụng')}</div>`
    +panel('Biểu đồ cước theo nhà mạng',monthLabel()+' · Theo toàn bộ kết quả lọc',telecomChart(t))
    +panel('Chi tiết cước dịch vụ',monthLabel(),table(pageRows,[['LoaiDichVu','Dịch vụ',false,v=>v==='DATA'?'Data':'Thoại'],['TenNhaMang','Nhà mạng'],['Vung','Miền'],['TenTinh','Khu vực'],['MaThueBao','Thuê bao'],['LoaiKhachHang','Loại KH'],['SoBanGhi','Bản ghi',true],['DoanhThu','Doanh thu (VND)',true]])
      +'<div class="page-tools"><span>Trang '+page+'/'+pages+' · '+number(t.length)+' dòng. Chỉ tiêu và CSV tính toàn bộ kết quả.</span><div><button data-telecom-page="'+(page-1)+'" '+(page<=1?'disabled':'')+'>Trang trước</button> <button data-telecom-page="'+(page+1)+'" '+(page>=pages?'disabled':'')+'>Trang sau</button></div></div>')
    +`<details class="panel extra-info"><summary>Đơn giá bình quân và phí giả lập</summary><div class="summary-line"><span>Đơn giá thoại bình quân</span><strong>${number(ratio(sum(t,'DoanhThuThoai'),sum(t,'SoPhutGoi')))} VND/phút</strong></div><div class="summary-line"><span>Đơn giá data bình quân</span><strong>${number(ratio(sum(t,'DoanhThuData'),sum(t,'DungLuongDataMB')))} VND/MB</strong></div><div class="summary-line"><span>Phí viễn thông giả lập</span><strong>${number(sum(t,'PhiVienThong'))} VND</strong></div><div class="summary-line"><span>Phí xử lý giả lập</span><strong>${number(sum(t,'PhiXuLy'))} VND</strong></div><p class="explain">Mẫu bằng 0 trả rỗng. Giá và phí phục vụ minh họa, không đủ để tính lợi nhuận; không cộng cước với tiền bán SIM/thẻ để gọi doanh thu hợp nhất.</p></details>`;
}
const cubeLabels={SoLuongBan:'Số lượng bán',DoanhThuBan:'Doanh thu bán (VND)',SoLuongTon:'Tồn cuối kỳ',SoLuongMua:'Số lượng mua',ThanhTienMua:'Thành tiền mua (VND)',DoanhThuCuoc:'Doanh thu cước (VND)',SoPhutGoi:'Phút thoại',DungLuongDataMB:'Dung lượng (MB)',SoCuocGoi:'Số cuộc thoại'};
function cube(){
  const d=state.cube;
  if(!d)return panel('Đối soát trực tiếp','Đọc hai hệ thống, không dùng kết quả cố định','<p class="muted">Đang truy vấn SQL và SSAS…</p>');
  const sql=d.sql[0];const rows=Object.keys(cubeLabels).map(key=>({Ten:cubeLabels[key],SQL:sql[key],Cube:d.cube[key],Khop:(sql[key]===null&&d.cube[key]===null)||(sql[key]!==null&&d.cube[key]!==null&&Math.abs(sql[key]-d.cube[key])<0.001)}));
  const ok=rows.every(r=>r.Khop);
  return panel('Kết quả đối soát · '+monthLabel(),'Phạm vi toàn bộ tháng, không áp dụng bộ lọc kho/dịch vụ',`<div class="cube-status"><span class="symbol">${ok?'✓':'!'}</span><div><h3>${ok?'SQL và cube khớp nhau':'Có chỉ tiêu lệch hoặc chưa đủ dữ liệu'}</h3><p class="panel-sub">${ok?'9/9 chỉ tiêu đúng ở cùng kỳ và ngữ cảnh.':'Cần kiểm tra dữ liệu SQL và lần process cube.'}</p></div></div><p class="explain">${escapeHTML(d.cubeSource)} · Đọc lúc ${utc(d.readAt)}</p>`,'<button id="read-cube" class="secondary">↻ Truy vấn lại</button>')
    +panel('So sánh từng chỉ tiêu','Tồn lấy ngày cuối tháng; các lượng phát sinh lấy cả tháng',table(rows,[['Ten','Chỉ tiêu'],['SQL','SQL Server',true],['Cube','SSAS',true],['Khop','Kết quả',false,v=>badge(v?'success':'failed')]])+'<p class="explain">Đối soát là truy vấn chỉ đọc. Nếu dữ liệu SQL mới nạp chưa xuất hiện trong cube, quản trị viên cần process rồi kiểm tra lại.</p>');
}
function dashboard(){
  const items=[['operations','▷','Nạp & xử lý cube','Chạy tác vụ và theo dõi tiến độ'],['batches','◷','Lịch sử nạp','Kiểm tra các đợt đã thực hiện'],['errors','!','Dữ liệu lỗi','Tra lý do dữ liệu bị cách ly'],['watermarks','⌖','Mốc nạp','Theo dõi ID nguồn đã xử lý']];
  return `<div class="metric-grid">${state.admin.facts.map(r=>metric('Bản ghi '+r.Ten.toLowerCase(),r.SoDong,'dòng','Trong kho dữ liệu')).join('')}</div>`+panel('Biểu đồ số bản ghi trong kho','Đơn vị: dòng; mỗi nghiệp vụ có mức hạt riêng',columnChart(state.admin.facts,'SoDong','Ten','dòng'))+panel('Chức năng quản trị','Quyền vận hành chỉ dành cho quản trị viên',`<div class="shortcut-grid">${items.map(([view,icon,label,text])=>`<a class="shortcut" href="#/${view}" data-go="${view}"><span class="icon">${icon}</span><span><strong>${label}</strong><small>${text}</small></span><span class="arrow">→</span></a>`).join('')}</div>`);
}
function operations(){
  const j=state.jobs[0],running=state.jobs.some(x=>x.status==='running');
  const actions=[['pipeline','Nạp dữ liệu','Nạp tăng dần, kiểm tra dữ liệu, xử lý cube và đối soát.','Bắt đầu nạp'],['process','Xử lý cube','Cập nhật cube từ kho hiện tại rồi kiểm tra kết quả.','Xử lý cube'],['verify','Đối soát dữ liệu','Kiểm tra SQL, cube và chạy các truy vấn MDX.','Chạy đối soát']];
  return panel('Chọn tác vụ','Các thao tác được chạy lần lượt',`<div class="action-cards">${actions.map(([action,title,text,label])=>`<div class="action-card"><h3>${title}</h3><p>${text}</p><button class="${action==='pipeline'?'primary':'secondary'}" data-action="${action}" ${running?'disabled':''}>${label}</button></div>`).join('')}</div>`)
    +panel('Trích nguồn OLTP','Dòng trích mới được đưa sang tầng cước; số fact nạp xem tại Lịch sử nạp',table(state.admin.connector||[],[['TrichID','Lượt',true],['BatDauUTC','Bắt đầu',false,utc],['TrangThai','Trạng thái',false,badge],['SoDongDoc','Đọc nguồn',true],['SoDongTrich','Trích mới',true],['SoNgayThem','Ngày thêm',true]]))
    +(j?panel('Tác vụ gần nhất',j.id,`<div class="summary-line"><span>Trạng thái</span>${badge(j.status)}</div>${j.steps.map(step=>`<div class="step"><span>${escapeHTML(step.title)}</span>${badge(step.status)}</div>`).join('')}<details class="help-details"><summary>Nhật ký chi tiết</summary><pre class="job-output">${escapeHTML(j.output||'Đang thực hiện…')}</pre></details>`):'');
}
function batches(){
  const rows=state.admin.batches.filter(r=>!state.adminStatus||r.TrangThai===state.adminStatus);
  return `<div class="filterbar"><div><label for="batch-status">Trạng thái đợt nạp</label><select id="batch-status"><option value="">Tất cả trạng thái</option>${options([{ID:'SUCCESS',Ten:'Thành công'},{ID:'FAILED',Ten:'Thất bại'},{ID:'RUNNING',Ten:'Đang chạy'}],state.adminStatus)}</select></div></div>`
    +panel('Các đợt nạp gần nhất','Tối đa 16 đợt; thời gian Việt Nam',table(rows,[['DotNapID','Đợt',true],['ThoiDiemBatDauUTC','Bắt đầu',false,utc],['TrangThai','Trạng thái',false,badge],['SoDongDoc','Đọc',true],['SoDongNap','Nạp mới',true],['SoDongLoi','Lỗi',true]])+help('Cách đọc số dòng','Số nạp mới chỉ đếm fact thêm mới. Replay có thể đọc nhiều nhưng nạp 0. Lượt thất bại được giữ lại để truy vết.'));
}
function errors(){
  const rows=state.admin.errors.filter(r=>!state.errorSource||r.HeThongNguon===state.errorSource);
  const sources=[...new Set(state.admin.errors.map(r=>r.HeThongNguon))].map(x=>({ID:x,Ten:x}));
  return `<div class="filterbar">${select('error-source','Hệ thống nguồn',sources,state.errorSource)}</div>`
    +panel('Dòng dữ liệu bị cách ly','Tối đa 12 dòng lỗi gần nhất',table(rows,[['DotNapID','Đợt',true],['HeThongNguon','Nguồn'],['DongNguonID','ID dòng nguồn',true],['LyDoLoi','Lý do',false,reason]])+help('Phạm vi danh sách','Đây là nhật ký lỗi ETL, không chỉ giới hạn trong tháng báo cáo. Các dòng lỗi được giữ để kiểm tra, không tự xóa.'));
}
function watermarks(){return panel('Mốc theo từng hệ thống','ID nguồn cuối đã xử lý thành công',table(state.admin.watermarks,[['HeThongNguon','Hệ thống'],['DongNguonCuoiID','ID nguồn cuối',true]])+help('Mốc nạp có ý nghĩa gì?','ETL đọc các ID mới hơn mốc. Mốc chỉ tiến khi transaction nạp thành công, không dựa trên ngày nghiệp vụ nên vẫn nhận được giao dịch đến muộn.'));}
function render(){
  if(!state.user)return;
  if(state.view==='analysis'){Analysis.render();return;}
  if(state.view.startsWith('oltp-')){Oltp.render();return;}
  const [title,description,crumb]=titles[state.view];$('page-title').textContent=title;$('page-description').textContent=description;$('breadcrumb').textContent=crumb;
  $('month').closest('.period').hidden=adminViews.has(state.view);
  document.querySelectorAll('#navigation [data-view]').forEach(a=>{const active=a.dataset.view===state.view;a.classList.toggle('active',active);if(active)a.setAttribute('aria-current','page');else a.removeAttribute('aria-current');});
  if(state.view==='overview'&&!state.data){$('content').innerHTML='';return;}
  if(adminViews.has(state.view)&&!state.admin){$('content').innerHTML=panel('Đang đọc dữ liệu','Nhật ký từ SQL Server','<p class="muted">Vui lòng chờ…</p>');return;}
  $('content').innerHTML=({dashboard,overview,sales,purchases,inventory,goods,telecom,cube,operations,batches,errors,watermarks}[state.view])();
  $('apply-goods')?.addEventListener('click',()=>{state.filters.warehouse=$('warehouse').value;loadReport(true);});
  $('apply-telecom')?.addEventListener('click',()=>{state.telecomPage=1;for(const k of ['type','network','region','subscriber'])state.filters[k]=$(k).value;loadReport(true);});
  document.querySelectorAll('[data-telecom-page]').forEach(b=>b.addEventListener('click',()=>{state.telecomPage=Number(b.dataset.telecomPage);render();}));
  $('clear-telecom')?.addEventListener('click',()=>{for(const k of ['type','network','region','subscriber'])state.filters[k]='';delete state.reportRuns.telecom;feedback('','');render();});
  const result=$('content').querySelector('.table-wrap,.empty')?.closest('.panel');if(result)result.id='report-results';
  setReportBusy(state.reportBusy);
  if(formViews.has(state.view))document.querySelectorAll('[data-export]').forEach(b=>b.disabled=!reportReady()||state.reportBusy);
  $('read-cube')?.addEventListener('click',loadCube);
  $('batch-status')?.addEventListener('change',e=>{state.adminStatus=e.target.value;render();});
  $('error-source')?.addEventListener('change',e=>{state.errorSource=e.target.value;render();});
  document.querySelectorAll('[data-export]').forEach(b=>b.onclick=()=>exportCSV(b.dataset.export));
  document.querySelectorAll('[data-action]').forEach(b=>b.onclick=()=>startJob(b.dataset.action));
}
function reportNotice(){
  const notes=[];
  if(['overview','inventory','goods'].includes(state.view)&&!snapshot())notes.push('Chưa đủ snapshot ngày chốt. Tổng tồn được giữ rỗng.');
  notice(notes.join(' '));
}
async function loadReport(explicit=false){
  if(state.reportBusy&&explicit)return;
  state.reportAbort?.abort();state.reportAbort=new AbortController();
  const version=++state.request,key=query(),view=state.view;error('');setReportBusy(true);
  if(explicit)feedback('running','Đang lấy báo cáo '+monthLabel()+' từ SQL Server…');
  try{
    const d=await api('/api/report?'+key,undefined,state.reportAbort.signal);if(version!==state.request)return;
    state.data=d;state.dataKey=key;if(explicit)state.reportRuns[view]=key;
    if(reportViews.has(state.view)){$('data-status').textContent=`${d.source} · Đọc lúc ${utc(d.readAt)}`;reportNotice();}
    render();
    if(explicit&&state.view===view){
      const rows=view==='telecom'?d.telecom:d.goods;
      feedback('success',rows.length?'Đã mở báo cáo '+monthLabel()+' · '+rows.length+' nhóm kết quả · '+utc(d.readAt):'Không có dữ liệu cho điều kiện đã chọn. Hãy đổi bộ lọc.');
      $('report-results')?.scrollIntoView({block:'nearest',behavior:'smooth'});
    }
  }catch(e){if(version===state.request){state.data=null;state.dataKey=null;delete state.reportRuns[view];if(reportViews.has(state.view)){render();$('data-status').textContent='Chưa lấy được báo cáo';error(e.message);feedback('failed','Không lấy được báo cáo. '+e.message);}}}
  finally{if(version===state.request)setReportBusy(false);}
}
async function loadCube(){const month=$('month').value;state.cube=null;render();error('');try{const data=await api('/api/cube?month='+month);if($('month').value!==month||!state.user)return;state.cube=data;if(state.view==='cube'){$('data-status').textContent='SQL Server ↔ SSAS · Đọc lúc '+utc(data.readAt);render();}}catch(e){if(state.view!=='cube'||$('month').value!==month||!state.user)return;error(e.message);$('content').innerHTML=panel('Chưa đọc được cube','Kiểm tra dịch vụ và quyền kết nối','<p>Hãy kiểm tra SQL/SSAS rồi chọn Làm mới dữ liệu.</p>');}}
async function loadAdmin(){error('');try{[state.admin,{jobs:state.jobs}]=await Promise.all([api('/api/admin?month='+$('month').value),api('/api/jobs')]);if(adminViews.has(state.view)){$('data-status').textContent=state.admin.source+' · Đọc lúc '+utc(state.admin.readAt);render();}watchJobs();}catch(e){error(e.message);}}
async function go(view,push=true){
  if(view==='analysis'){
    state.request++;state.reportAbort?.abort();setReportBusy(false);state.view=view;error('');notice('');feedback('','');
    const hash='#/analysis';if(location.hash!==hash){if(push)history.pushState(null,'',hash);else history.replaceState(null,'',hash);}
    $('reports-menu').open=true;$('oltp-menu').open=false;$('admin-nav').open=false;
    document.querySelector('.sidebar').classList.remove('menu-open');$('menu-toggle').setAttribute('aria-expanded','false');
    Analysis.enter();return;
  }
  if(view.startsWith('oltp-')&&Oltp.sections[view.slice(5)]){
    state.view=view;error('');notice('');feedback('','');
    const hash='#/'+view;if(location.hash!==hash){if(push)history.pushState(null,'',hash);else history.replaceState(null,'',hash);}
    $('oltp-menu').open=true;$('reports-menu').open=false;$('admin-nav').open=false;
    document.querySelector('.sidebar').classList.remove('menu-open');$('menu-toggle').setAttribute('aria-expanded','false');
    await Oltp.load();return;
  }
  if(view==='admin')view='operations';if(!titles[view])view='overview';
  if(adminViews.has(view)&&state.user.role!=='admin')view='overview';
  if(state.view!==view&&state.reportBusy){state.request++;state.reportAbort?.abort();setReportBusy(false);}
  state.view=view;error('');notice('');feedback('','');
  const hash='#/'+view;if(location.hash!==hash){if(push)history.pushState(null,'',hash);else history.replaceState(null,'',hash);}
  if(adminViews.has(view)){$('admin-nav').open=true;$('reports-menu').open=false;}
  else if(reportViews.has(view)&&view!=='overview'){$('reports-menu').open=true;$('admin-nav').open=false;}
  document.querySelector('.sidebar').classList.remove('menu-open');$('menu-toggle').setAttribute('aria-expanded','false');
  if(reportViews.has(view)){
    if(state.dataKey!==query())state.data=null;
    render();if(formViews.has(view)&&!reportReady()){$('data-status').textContent='Chọn điều kiện và bấm Xem báo cáo';return;}if(!state.data)await loadReport();else{$('data-status').textContent=state.data.source+' · Đọc lúc '+utc(state.data.readAt);reportNotice();}
  }else{render();if(view==='cube')await loadCube();if(adminViews.has(view))await loadAdmin();}
}
async function startJob(action){
  const messages={pipeline:'Nạp tăng dần hai luồng, kiểm tra dữ liệu, xử lý cube và đối soát? Không chạy lại seed.',process:'Xử lý cube hiện tại và đối soát số liệu?',verify:'Chạy kiểm tra SQL/cube và xuất lại kết quả MDX?'};
  if(!confirm(messages[action]))return;
  try{const {job}=await api('/api/jobs',{action});state.jobs.unshift(job);render();watchJobs();}catch(e){error(e.message);}
}
function watchJobs(){clearTimeout(poll);if(!state.user||state.user.role!=='admin'||!state.jobs.some(j=>j.status==='running'))return;poll=setTimeout(async()=>{try{const {jobs}=await api('/api/jobs');state.jobs=jobs;if(state.view==='operations')render();if(!jobs.some(j=>j.status==='running')){state.dataKey=null;state.cube=null;state.catalog=await api('/api/catalog');updatePeriods();await loadAdmin();}else watchJobs();}catch(e){error(e.message);}},2000);}
async function exportCSV(kind){try{const r=await fetch('/api/export?kind='+kind+'&'+query());if(!r.ok){const d=await r.json();throw new Error(d.error);}const url=URL.createObjectURL(await r.blob());const a=document.createElement('a');a.href=url;a.download=({sales:'ban-hang-',purchases:'mua-hang-',inventory:'ton-kho-',goods:'doi-chieu-hang-hoa-',telecom:'cuoc-'}[kind])+$('month').value+'.csv';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}catch(e){error(e.message);}}
function showLogin(){state.reportAbort?.abort();clearTimeout(poll);state.request++;state.user=null;state.data=null;state.dataKey=null;state.reportRuns={};state.reportBusy=false;setReportBusy(false);feedback('','');state.admin=null;state.cube=null;state.jobs=[];state.view='overview';state.adminStatus='';state.errorSource='';state.filters={warehouse:'0',type:'',network:'',region:'',subscriber:''};$('workspace').hidden=true;$('login-screen').hidden=false;$('password').value='';}
async function enter(user){
  state.user=user;const admin=user.role==='admin';
  $('login-screen').hidden=true;$('workspace').hidden=false;
  $('role-badge').textContent=admin?'Quản trị viên':'Nhân viên';$('workspace-label').textContent=admin?'KHÔNG GIAN QUẢN TRỊ VIÊN':'KHÔNG GIAN NHÂN VIÊN';$('admin-nav').hidden=!admin;
  const home=$('navigation').querySelector('[data-home]')||$('navigation').querySelector('[data-view="overview"]');
  home.dataset.home='true';home.dataset.view=admin?'dashboard':'overview';home.href=admin?'#/dashboard':'#/overview';home.innerHTML='<span>⌂</span>'+(admin?'Trang quản trị':'Trang nhân viên');
  $('admin-nav').open=admin;$('reports-menu').open=!admin;error('');
  try{state.catalog=await api('/api/catalog');updatePeriods();const route=location.hash.slice(2);await go(!route||route==='overview'||route==='dashboard'?(admin?'dashboard':'overview'):route,false);}catch(e){error(e.message);}
}
$('login-form').addEventListener('submit',async event=>{event.preventDefault();$('login-error').textContent='';$('login-button').disabled=true;try{const user=await api('/api/login',{username:$('username').value,password:$('password').value});$('password').value='';await enter(user);}catch(e){$('login-error').textContent=e.message;}finally{$('login-button').disabled=false;}});
$('logout').onclick=async()=>{try{await api('/api/logout',{});}finally{history.replaceState(null,'','#/overview');showLogin();}};
function follow(event,attribute){const link=event.target.closest('['+attribute+']');if(!link||event.ctrlKey||event.metaKey||event.shiftKey||event.altKey)return;event.preventDefault();go(link.dataset[attribute==='data-view'?'view':'go']);}
$('navigation').addEventListener('click',e=>follow(e,'data-view'));
$('content').addEventListener('click',e=>follow(e,'data-go'));
$('menu-toggle').onclick=()=>{const open=document.querySelector('.sidebar').classList.toggle('menu-open');$('menu-toggle').setAttribute('aria-expanded',String(open));};
window.addEventListener('popstate',()=>{if(state.user)go(location.hash.slice(2)||'overview',false);});
$('month').onchange=async()=>{state.cube=null;await go(state.view,false);};
$('refresh').onclick=async()=>{if(state.view==='analysis')await Analysis.load();else if(state.view.startsWith('oltp-'))await Oltp.load(true);else if(reportViews.has(state.view))await loadReport(formViews.has(state.view));else if(state.view==='cube')await loadCube();else await loadAdmin();};
$('retry-report').onclick=()=>loadReport(true);
(async()=>{
  try{const r=await fetch('/api/info');const info=r.ok?await r.json():null;if(info?.version!=='nhamangdw-trien-khai-11')throw new Error('old-server');}
  catch{showLogin();$('login-error').textContent='Phiên máy chủ đang chạy bản cũ. Dừng cửa sổ demo bằng Ctrl+C, mở lại Mo_Demo.cmd rồi tải lại trang.';return;}
  try{await enter(await api('/api/me'));}catch{showLogin();}
})();
