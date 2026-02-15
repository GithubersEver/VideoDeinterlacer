<h2>Installation Procedure for macOS</h2>

<h3>1. Install Homebrew</h3>
<p>Open <b>Terminal</b> and run:</p>

<pre><code>/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"</code></pre>

<p>This will:</p>
<ul>
  <li>Install Homebrew</li>
  <li>Install required developer tools automatically</li>
</ul>

<p><b>Apple Silicon Macs (M1/M2/M3/M4)</b> must add Homebrew to PATH.</p>
<p>Run the command shown at the end of installation (usually):</p>

<pre><code>echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.zprofile
eval "$(/opt/homebrew/bin/brew shellenv)"</code></pre>

<h3>2. Install FFmpeg</h3>

<pre><code>brew install ffmpeg</code></pre>

<h3>Optional (Recommended)</h3>

<pre><code>brew update
brew upgrade</code></pre>


<hr>

<h2>Installation Procedure for Windows</h2>

<h3>1. Download FFmpeg</h3>
<p>Download from:</p>
<p>
  <a href="https://www.gyan.dev/ffmpeg/builds/" target="_blank">
    https://www.gyan.dev/ffmpeg/builds/
  </a>
</p>

<p>Download:</p>
<ul>
  <li><code>ffmpeg-git-full.7z</code> (or latest build)</li>
</ul>

<h3>2. Extract</h3>
<ul>
  <li>Right-click → Extract (use 7-Zip or WinRAR)</li>
  <li>Move folder to:</li>
</ul>

<pre><code>C:\ffmpeg</code></pre>

<h3>3. Add FFmpeg to PATH</h3>
<ol>
  <li>Press <b>Win + S</b></li>
  <li>Search: <i>Environment Variables</i></li>
  <li>Open: <b>Edit the system environment variables</b></li>
  <li>Click <b>Environment Variables</b></li>
  <li>Under <b>System variables</b> select <b>Path</b></li>
  <li>Click <b>Edit</b></li>
  <li>Click <b>New</b></li>
  <li>Add:</li>
</ol>

<pre><code>C:\ffmpeg\bin</code></pre>
