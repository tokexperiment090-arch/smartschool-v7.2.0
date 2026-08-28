<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title><?php echo htmlspecialchars($page['title']); ?> | Riyo</title>
  <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css">
  <style>body{background:#f4f6f9;font-family:Segoe UI,Arial}.wrap{max-width:1100px;margin:30px auto;background:#fff;padding:25px;border-radius:8px;box-shadow:0 2px 8px rgba(0,0,0,.08)}.brand{color:#7367f0}.topbar{background:#7367f0;color:#fff;padding:12px 25px;display:flex;justify-content:space-between}table{width:100%;border-collapse:collapse;margin-top:15px}th,td{border:1px solid #e3e3e3;padding:8px}.tag{display:inline-block;background:#eee;border-radius:10px;padding:2px 8px;margin:2px;font-size:12px}</style>
</head>
<body>
  <div class="topbar"><div><b>Riyo</b> &nbsp; Mustaqbal Portal Clone</div><a href="<?php echo base_url('portal'); ?>" class="text-white">← All Modules</a></div>
  <div class="wrap">
    <h3 class="brand"><?php echo htmlspecialchars($page['title']); ?></h3>
    <form id="f">
      <input type="hidden" name="page_id" value="<?php echo $page['id']; ?>">
      <?php foreach (json_decode($page['fields'], true) as $f): ?>
        <div class="form-group">
          <label><?php echo htmlspecialchars($f['label']); ?></label>
          <?php if ($f['type']=='textarea'): ?>
            <textarea class="form-control" name="field_<?php echo $f['name']; ?>"></textarea>
          <?php elseif ($f['type']=='select'): ?>
            <select class="form-control" name="field_<?php echo $f['name']; ?>">
              <option value="">-- select --</option>
              <?php foreach (($f['options']??[]) as $o): ?><option><?php echo htmlspecialchars($o); ?></option><?php endforeach; ?>
            </select>
          <?php else: ?>
            <input class="form-control" type="<?php echo $f['type']=='number'?'number':($f['type']=='date'?'date':'text'); ?>" name="field_<?php echo $f['name']; ?>">
          <?php endif; ?>
        </div>
      <?php endforeach; ?>
      <button class="btn btn-primary" type="submit">Save</button>
    </form>
    <h5 class="mt-4">Records</h5>
    <div id="rows"></div>
    <?php if (!empty($mode)): ?>
      <h5 class="mt-4 text-<?php echo $mode=='report'?'primary':'secondary'; ?>">
        <?php echo $mode=='report'?'Generated Report':'Linked Records'; ?>
      </h5>
      <?php if ($mode=='report' && $report !== null): ?>
        <table><tr><th>Account</th><th>Balance (Dr+ / Cr-)</th></tr>
        <?php foreach ($report as $acc=>$bal): ?><tr><td><?php echo htmlspecialchars($acc); ?></td><td><?php echo number_format($bal,2); ?></td></tr><?php endforeach; ?>
        </table>
      <?php else: ?>
        <table><tr><th>#</th><th>Data</th></tr>
        <?php foreach ($source_records as $i=>$r):
          $obj=array(); foreach (json_decode($r['data'],true)?:array() as $p){$obj[$p['name']]=$p['value'];} ?>
          <tr><td><?php echo $i+1; ?></td><td><?php foreach($obj as $k=>$v) echo '<span class="tag">'.htmlspecialchars($k).': '.htmlspecialchars($v).'</span> '; ?></td></tr>
        <?php endforeach; ?>
        </table>
      <?php endif; ?>
    <?php endif; ?>
  </div>
  <script src="https://code.jquery.com/jquery-3.5.1.min.js"></script>
  <script>
  $(function(){
    load();
    $('#f').submit(function(e){
      e.preventDefault();
      var d={page_id:<?php echo $page['id']; ?>, data: JSON.stringify($(this).serializeArray())};
      $.post('<?php echo base_url('portal/save'); ?>', d, function(r){
        if(r.status){ $('#f')[0].reset(); load(); }
      },'json');
    });
  });
  function load(){
    $.getJSON('<?php echo base_url('portal/list/'.$page['id']); ?>', function(r){
      var h='<table><tr><th>#</th><th>Data</th><th></th></tr>';
      (r.rows||[]).forEach(function(x,i){
        var obj={}; try{ x.data.replace(/field_([^=]+)=([^&]+)/g,function(m,k,v){obj[decodeURIComponent(k)]=decodeURIComponent(v);}); }catch(e){}
        // JSON array form
        try{ JSON.parse(x.data).forEach(function(p){obj[p.name]=p.value;}); }catch(e){}
        var tags=Object.keys(obj).map(function(k){return '<span class=\"tag\">'+k+': '+obj[k]+'</span>';}).join(' ');
        h+='<tr><td>'+(i+1)+'</td><td>'+tags+'</td><td><a href=\"#\" onclick=\"del('+x.id+');return false\">delete</a></td></tr>';
      });
      h+='</table>';
      $('#rows').html(h);
    });
  }
  function del(id){ $.get('<?php echo base_url('portal/delete'); ?>/'+id, function(){ load(); }); }
  </script>
</body>
</html>
