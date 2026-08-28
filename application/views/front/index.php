<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Riyo Center For Special Needs</title>
  <link href="https://fonts.googleapis.com/css2?family=Poppins:wght@300;500;700&display=swap" rel="stylesheet">
  <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.5.2/css/bootstrap.min.css">
  <style>
    body{font-family:'Poppins',Arial;margin:0}
    .hero{background:linear-gradient(135deg,#7367f0,#9e95f5);color:#fff;padding:80px 20px;text-align:center}
    .hero h1{font-weight:700;font-size:2.6rem}
    .btn-portal{background:#fff;color:#7367f0;font-weight:600;padding:12px 30px;border-radius:30px;text-decoration:none;display:inline-block;margin-top:20px}
    .section{padding:60px 20px;max-width:1000px;margin:auto}
    .card{border:none;box-shadow:0 4px 18px rgba(0,0,0,.08);border-radius:12px;padding:25px;margin:15px}
    .pill{background:#7367f0;color:#fff;border-radius:20px;padding:6px 16px;font-size:13px}
    .feat{display:flex;gap:15px;align-items:center;margin:12px 0}
    .feat .ic{width:46px;height:46px;background:#efeaff;border-radius:12px;display:flex;align-items:center;justify-content:center;color:#7367f0;font-weight:700}
  </style>
</head>
<body>
  <div class="hero">
    <span class="pill">Kaafiye Technology Center Partner</span>
    <h1>Riyo Center For Special Needs</h1>
    <p class="lead">Compassionate education, therapy & care for every learner.</p>
    <a class="btn-portal" href="<?php echo base_url('portal'); ?>">Customer Portal →</a>
    <a class="btn-portal" style="background:transparent;color:#fff;border:2px solid #fff;margin-left:10px" href="<?php echo base_url('site/login'); ?>">Staff Login</a>
  </div>

  <div class="section">
    <h3 style="color:#7367f0">What we offer</h3>
    <div class="row">
      <div class="col-md-4"><div class="card"><div class="feat"><div class="ic">A</div><div><b>Individualized Programs</b><br>Tailored learning plans per child.</div></div></div></div>
      <div class="col-md-4"><div class="card"><div class="feat"><div class="ic">B</div><div><b>Therapy & Support</b><br>Speech, occupational & behavioral therapy.</div></div></div></div>
      <div class="col-md-4"><div class="card"><div class="feat"><div class="ic">C</div><div><b>Family Engagement</b><br>Parents portal & progress tracking.</div></div></div></div>
    </div>
  </div>

  <div class="section" id="contact">
    <h3 style="color:#7367f0">Get in touch</h3>
    <?php if ($this->session->flashdata('ok')): ?><div class="alert alert-success"><?php echo $this->session->flashdata('ok'); ?></div><?php endif; ?>
    <form method="post" action="<?php echo base_url('front/inquiry'); ?>">
      <div class="form-group"><input class="form-control" name="name" placeholder="Your name" required></div>
      <div class="form-group"><input class="form-control" name="email" type="email" placeholder="Email" required></div>
      <div class="form-group"><input class="form-control" name="phone" placeholder="Phone"></div>
      <div class="form-group"><textarea class="form-control" name="message" placeholder="How can we help?" required></textarea></div>
      <button class="btn btn-primary" type="submit" style="background:#7367f0;border:none">Send Inquiry</button>
    </form>
  </div>

  <footer style="background:#2b2b3a;color:#bbb;text-align:center;padding:25px">
    © Riyo Center For Special Needs — powered by Riyo (Kaafiye portal clone)
  </footer>
</body>
</html>
