---
---
<h1>{{< param Author >}}</h1>
<div id="resume-summary">Technologist and purveyor of fine automation.</div>
<div id="resume-contact">
  <div class="resume-contact-pair">
    <div class="resume-contact-label"><span class="fas fa-globe"></span></div>
    <div class="resume-contact-detail">
      <a rel="noopener" href="{{< param social.website >}}" target="_blank">{{< param social.website_short >}}</a>
    </div>
  </div>
  <div class="resume-contact-pair">
    <div class="resume-contact-label"><span class="fas fa-envelope"></span></div>
    <div class="resume-contact-detail">
      <a href="mailto:{{< param social.email >}}">{{< param social.email >}}</a>
    </div>
  </div>
  <div class="resume-contact-pair">
    <div class="resume-contact-label"><span class="fab fa-github"></span></div>
    <div class="resume-contact-detail">
      <a href="{{< param social.github >}}">{{< param social.github_short >}}</a>
    </div>
  </div>
  <div class="resume-contact-pair">
    <div class="resume-contact-label"><span class="fab fa-linkedin"></span></div>
    <div class="resume-contact-detail">
      <a href="{{< param social.linkedin >}}">{{< param social.linkedin_short >}}</a>
    </div>
  </div>
  <div class="resume-contact-pair">
    <div class="resume-contact-label"><span class="fas fa-location-dot"></span></div>
    <div class="resume-contact-detail">{{< param location >}}</div>
  </div>
  {{< condl-contact "fas fa-phone" "social.phone" >}}
</div>
