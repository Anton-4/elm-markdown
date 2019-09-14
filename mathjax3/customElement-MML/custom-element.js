class CustomElement extends HTMLElement {
  constructor() {
    super();
  }

  connectedCallback() {
    this.template = document.createElement('template');
    this.template.innerHTML = this.innerHTML;
    this.attachShadow({mode: "open"}).appendChild(this.template.content.cloneNode(true));
    MathJax.typesetShadow(this.shadowRoot);
  }
}

customElements.define('custom-element', CustomElement);
