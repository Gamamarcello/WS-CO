import{$ as s,A as f,S as d,I as u,T as h,X as g,V as y,M as w,d as b,a as v,b as S,G as x}from"./vendor.4f587092.js";const O=function(){const o=document.createElement("link").relList;if(o&&o.supports&&o.supports("modulepreload"))return;for(const e of document.querySelectorAll('link[rel="modulepreload"]'))n(e);new MutationObserver(e=>{for(const a of e)if(a.type==="childList")for(const l of a.addedNodes)l.tagName==="LINK"&&l.rel==="modulepreload"&&n(l)}).observe(document,{childList:!0,subtree:!0});function r(e){const a={};return e.integrity&&(a.integrity=e.integrity),e.referrerpolicy&&(a.referrerPolicy=e.referrerpolicy),e.crossorigin==="use-credentials"?a.credentials="include":e.crossorigin==="anonymous"?a.credentials="omit":a.credentials="same-origin",a}function n(e){if(e.ep)return;e.ep=!0;const a=r(e);fetch(e.href,a)}};O();const k="pk.eyJ1IjoiZWxwYmF0aXN0YSIsImEiOiJja3gyZHl5OXYxbm5yMnFxOTFtZWhqbWlhIn0.bbHJjnHrt_d9iqu4hBZgyw",I="../img/map-marker-blue-32.png",j="../img/map-marker-orange-32.png",P=[-75.595483,6.269356],p="http://api.addressforall.org/test/_sql/rpc/",T={search:p+"search",search_bounded:p+"search_bounded"};window.jQuery=window.$=s;const _=new f({collapsible:!1}),F=new d({image:new u({anchor:[.5,31],anchorXUnits:"fraction",anchorYUnits:"pixels",src:I})}),L=new d({image:new u({anchor:[.5,31],anchorXUnits:"fraction",anchorYUnits:"pixels",src:j})}),M=new h({source:new g({attributions:'\xA9 <a href="https://www.mapbox.com/map-feedback/">Mapbox</a> \xA9 <a href="https://www.openstreetmap.org/copyright">OpenStreetMap contributors</a>',url:"https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token="+k})}),i=new y({style:F}),c=new w({controls:b({attribution:!1}).extend([_]),target:"map",layers:[M,i],view:new v({projection:"EPSG:4326",center:P,zoom:15})}),N=(t,o)=>{s.ajax({url:T.search_bounded,type:"POST",processData:!1,contentType:"application/json",cache:!0,jsonp:!1,data:JSON.stringify({_q:t,viewbox:o,lim:1e3}),dataType:"json",crossDomain:!0,success:function(r){if(r.features){i.setSource(null),i.setSource(new S({features:new x().readFeatures(r)}));let n=r.features.map(e=>'<li id="'+e.properties._id+'" class="feature list-group-item d-flex justify-content-between align-items-start"  data-coordinates="'+JSON.stringify(e.geometry.coordinates)+'"><div class="ms-2 me-auto"><div class="address fw-bold">'+e.properties.address+'</div><div class="display_name fw-lighter">'+e.properties.display_name+" "+e.properties.barrio+'</div></div><span class="badge bg-info bg-opacity-85 rounded-pill">'+Math.round(e.properties.similarity*100)+"%</span></li>");s("#search").removeClass("is-invalid"),s("#afo-results").show(),s("#clear-btn").show(),s("#afo-results").children("ul").empty().show(),s("#afo-results").children("ul").append(n),s(".display_name").mark(t.split(" "))}else s("#search").addClass("is-invalid"),m()}})},C=t=>{let o=s(t.target);t.stopPropagation(),clearTimeout(o.data("timeout")),o.data("timeout",setTimeout(function(){let r=o.val();r.length>=3&&N(r,c.getView().calculateExtent(c.getSize()))},200))};s("#search").on("keyup",function(t){C(t)});s(document).on("keydown","form",function(t){return t.key!="Enter"});s(document).on("click","#clear-btn",function(t){return t.stopPropagation(),t.stopImmediatePropagation(),m(),s("#search").val(""),c.getView().setZoom(15),s(t.currentTarget).hide(),!1});s(document).on("click",".feature",function(t){t.stopPropagation(),t.stopImmediatePropagation();let o=s(t.currentTarget),r=c.getView(),n=JSON.parse(o.attr("data-coordinates"));i.getSource().getClosestFeatureToCoordinate(n).setStyle(L),r.setCenter(n),r.setZoom(20),o.addClass("selected")});const m=()=>{i.setSource(null),s("#afo-results").children("ul").empty().hide()};
//# sourceMappingURL=index.274015c5.js.map